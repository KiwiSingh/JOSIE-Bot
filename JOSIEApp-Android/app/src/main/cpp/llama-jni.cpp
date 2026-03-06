#include "llama.h"
#include <algorithm>
#include <android/log.h>
#include <chrono>
#include <jni.h>
#include <string>
#include <thread>
#include <vector>

#define LOG_TAG "JOSIE_LLAMA"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static llama_model *model = nullptr;
static llama_context *ctx = nullptr;
static std::vector<llama_token> last_tokens; // For prefix caching

extern "C" JNIEXPORT jboolean JNICALL Java_com_josie_ai_LlamaNative_loadModel(
    JNIEnv *env, jobject thiz, jstring model_path) {
  const char *path = env->GetStringUTFChars(model_path, nullptr);
  LOGI("Loading model from %s", path);

  llama_backend_init();

  auto mparams = llama_model_default_params();
  model = llama_model_load_from_file(path, mparams);

  if (!model) {
    LOGE("Failed to load model from %s", path);
    env->ReleaseStringUTFChars(model_path, path);
    return JNI_FALSE;
  }

  auto cparams = llama_context_default_params();
  cparams.n_ctx = 2048;
  cparams.n_batch = 1024;
  cparams.n_ubatch = 512; // Standard physical batch limit

  unsigned int cores = std::thread::hardware_concurrency();
  cparams.n_threads = std::max(1u, cores / 2);
  cparams.n_threads_batch = std::max(1u, cores);
  LOGI("Context parameters: threads=%d/%d, ctx=%d, ubatch=%d",
       cparams.n_threads, cparams.n_threads_batch, cparams.n_ctx,
       cparams.n_ubatch);

  ctx = llama_init_from_model(model, cparams);

  env->ReleaseStringUTFChars(model_path, path);
  return ctx != nullptr ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT void JNICALL Java_com_josie_ai_LlamaNative_generateStream(
    JNIEnv *env, jobject thiz, jstring prompt, jobject callback) {

  if (!ctx || !model) {
    LOGE("Context or model not initialized");
    return;
  }

  const char *p_str = env->GetStringUTFChars(prompt, nullptr);
  int p_bytes = strlen(p_str);

  // Tokenize prompt
  const int n_tokens_max = p_bytes + 128;
  std::vector<llama_token> tokens(n_tokens_max);
  int n_tokens = llama_tokenize(llama_model_get_vocab(model), p_str, p_bytes,
                                tokens.data(), tokens.size(), true, true);
  if (n_tokens < 0) {
    LOGE("Tokenization failed");
    env->ReleaseStringUTFChars(prompt, p_str);
    return;
  }
  tokens.resize(n_tokens);
  env->ReleaseStringUTFChars(prompt, p_str);

  // --- PREFIX CACHING (Persistent Memory) ---
  int n_keep = 0;
  int min_length = std::min(tokens.size(), last_tokens.size());
  for (int i = 0; i < min_length; i++) {
    if (tokens[i] != last_tokens[i])
      break;
    n_keep++;
  }

  // Clear mismatched tokens from KV cache
  if (n_keep < last_tokens.size()) {
    llama_memory_seq_rm(llama_get_memory(ctx), -1, n_keep, -1);
  }

  int n_past = n_keep;
  int n_decode = tokens.size() - n_past;

  // Force evaluation of at least the last token to get logits
  if (n_decode == 0 && !tokens.empty()) {
    n_past -= 1;
    n_decode = 1;
    llama_memory_seq_rm(llama_get_memory(ctx), -1, n_past, -1);
  }

  LOGI("Cache hit: kept %d tokens, decoding %d new tokens.", n_keep, n_decode);

  // --- SAFE PROMPT EVALUATION ---
  int last_eval_idx = 0;
  if (n_decode > 0) {
    int chunk_size = 512;
    llama_batch batch = llama_batch_init(chunk_size, 0, 1);

    for (int i = 0; i < n_decode; i += chunk_size) {
      int n_eval = std::min(chunk_size, n_decode - i);
      batch.n_tokens = n_eval;

      for (int j = 0; j < n_eval; j++) {
        batch.token[j] = tokens[n_past + i + j];
        batch.pos[j] = n_past + i + j;
        batch.n_seq_id[j] = 1;
        batch.seq_id[j][0] = 0;
        batch.logits[j] =
            (i + j == n_decode - 1); // Logits only for the very last token
      }

      if (llama_decode(ctx, batch) != 0) {
        LOGE("llama_decode failed during prompt ingestion");
        llama_batch_free(batch);
        last_tokens.clear();
        return;
      }
      last_eval_idx = n_eval - 1;
    }
    llama_batch_free(batch);
  }

  last_tokens = tokens;

  // --- SAMPLING & GENERATION ---
  auto smpl = llama_sampler_chain_init(llama_sampler_chain_default_params());
  llama_sampler_chain_add(smpl,
                          llama_sampler_init_penalties(512, 1.05f, 0.0f, 0.0f));
  llama_sampler_chain_add(smpl, llama_sampler_init_min_p(0.05f, 1));
  llama_sampler_chain_add(smpl, llama_sampler_init_temp(0.80f));
  llama_sampler_chain_add(smpl, llama_sampler_init_dist(time(NULL)));

  jclass callbackClass = env->GetObjectClass(callback);
  jmethodID onTokenMethod = env->GetMethodID(callbackClass, "onToken", "([B)V");

  int n_cur = tokens.size();
  int n_gen = 0;
  llama_batch gen_batch = llama_batch_init(1, 0, 1); // Init once!

  while (n_cur < llama_n_ctx(ctx) && n_gen < 1024) {
    int sampling_idx = (n_gen == 0) ? last_eval_idx : 0;
    llama_token id = llama_sampler_sample(smpl, ctx, sampling_idx);
    llama_sampler_accept(smpl, id);

    if (llama_vocab_is_eog(llama_model_get_vocab(model), id))
      break;

    char piece[128];
    int n_chars = llama_token_to_piece(llama_model_get_vocab(model), id, piece,
                                       sizeof(piece), 0, false);

    if (n_chars > 0) {
      jbyteArray jbytes = env->NewByteArray(n_chars);
      env->SetByteArrayRegion(jbytes, 0, n_chars,
                              reinterpret_cast<const jbyte *>(piece));
      env->CallVoidMethod(callback, onTokenMethod, jbytes);
      env->DeleteLocalRef(jbytes);
    }

    last_tokens.push_back(id); // Keep cache in sync with generated text!

    gen_batch.n_tokens = 1;
    gen_batch.token[0] = id;
    gen_batch.pos[0] = n_cur;
    gen_batch.n_seq_id[0] = 1;
    gen_batch.seq_id[0][0] = 0;
    gen_batch.logits[0] = true;

    if (llama_decode(ctx, gen_batch) != 0) {
      LOGE("Token decode failed");
      break;
    }
    n_cur++;
    n_gen++;
  }

  llama_batch_free(gen_batch); // Free once!
  llama_sampler_free(smpl);
}

extern "C" JNIEXPORT void JNICALL
Java_com_josie_ai_LlamaNative_unload(JNIEnv *env, jobject thiz) {
  if (ctx)
    llama_free(ctx);
  if (model)
    llama_model_free(model);
  ctx = nullptr;
  model = nullptr;
  last_tokens.clear(); // Reset cache for next model load
}
