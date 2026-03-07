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
static std::vector<llama_token> last_tokens;

extern "C" JNIEXPORT jboolean JNICALL
Java_com_josie_ai_LlamaNative_loadModel(JNIEnv *env, jobject thiz, jstring model_path) {

    const char *path = env->GetStringUTFChars(model_path, nullptr);
    LOGI("Loading model from %s", path);

    llama_backend_init();

    auto mparams = llama_model_default_params();

    // ---- GPU ACCELERATION ----
    mparams.n_gpu_layers = 12;

    model = llama_model_load_from_file(path, mparams);

    if (!model) {
        LOGE("Failed to load model");
        env->ReleaseStringUTFChars(model_path, path);
        return JNI_FALSE;
    }

    LOGI("Model loaded: layers=%d embd=%d vocab=%d",
         llama_model_n_layer(model),
         llama_model_n_embd(model),
         llama_vocab_n_tokens(llama_model_get_vocab(model)));

    auto cparams = llama_context_default_params();

    cparams.n_ctx = 2048;

    // Mobile-safe batch sizing
    cparams.n_batch = 512;
    cparams.n_ubatch = 256;

    unsigned int cores = std::thread::hardware_concurrency();

    cparams.n_threads = std::max(2u, cores - 2);
    cparams.n_threads_batch = cores;

    LOGI("Context parameters: threads=%d/%d ctx=%d batch=%d ubatch=%d",
         cparams.n_threads,
         cparams.n_threads_batch,
         cparams.n_ctx,
         cparams.n_batch,
         cparams.n_ubatch);

    ctx = llama_init_from_model(model, cparams);

    if (!ctx) {
        LOGE("Failed to create llama context");
        env->ReleaseStringUTFChars(model_path, path);
        return JNI_FALSE;
    }

    env->ReleaseStringUTFChars(model_path, path);
    return JNI_TRUE;
}

extern "C" JNIEXPORT void JNICALL
Java_com_josie_ai_LlamaNative_generateStream(JNIEnv *env, jobject thiz,
                                             jstring prompt, jobject callback) {

    if (!ctx || !model) {
        LOGE("Context or model not initialized");
        return;
    }

    const char *p_str = env->GetStringUTFChars(prompt, nullptr);
    int p_bytes = strlen(p_str);

    const int n_tokens_max = p_bytes + 4;
    std::vector<llama_token> tokens(n_tokens_max);

    int n_tokens = llama_tokenize(
            llama_model_get_vocab(model),
            p_str,
            p_bytes,
            tokens.data(),
            tokens.size(),
            true,
            true);

    if (n_tokens < 0) {
        LOGE("Tokenization failed");
        env->ReleaseStringUTFChars(prompt, p_str);
        return;
    }

    tokens.resize(n_tokens);
    env->ReleaseStringUTFChars(prompt, p_str);

    if (tokens.size() >= (size_t)llama_n_ctx(ctx) - 1) {
        LOGE("Prompt exceeds context window");
        return;
    }

    int n_keep = 0;

    for (int i = 0; i < (int)std::min(tokens.size(), last_tokens.size()); i++) {
        if (tokens[i] != last_tokens[i]) break;
        n_keep++;
    }

    if (n_keep < (int)last_tokens.size()) {
        llama_memory_seq_rm(llama_get_memory(ctx), -1, n_keep, -1);
    }

    int n_past = n_keep;
    int n_decode = tokens.size() - n_past;

    if (n_decode == 0 && !tokens.empty()) {
        n_past -= 1;
        n_decode = 1;
        llama_memory_seq_rm(llama_get_memory(ctx), -1, n_past, -1);
    }

    LOGI("Context Info: n_tokens=%zu n_keep=%d n_past=%d n_decode=%d",
         tokens.size(), n_keep, n_past, n_decode);

    int last_eval_idx = 0;

    if (n_decode > 0) {

        const int chunk_size = 128;

        for (int i = 0; i < n_decode; i += chunk_size) {

            int n_eval = std::min(chunk_size, n_decode - i);

            llama_batch batch = llama_batch_init(n_eval, 0, 1);
            batch.n_tokens = n_eval;

            for (int j = 0; j < n_eval; j++) {

                batch.token[j] = tokens[n_past + i + j];
                batch.pos[j] = n_past + i + j;

                batch.n_seq_id[j] = 1;
                batch.seq_id[j][0] = 0;

                batch.logits[j] = (i + j == n_decode - 1);
            }

            int res = llama_decode(ctx, batch);

            if (res != 0) {
                LOGE("llama_decode failed at index %d", i);
                llama_batch_free(batch);
                last_tokens.clear();
                return;
            }

            last_eval_idx = n_eval - 1;
            llama_batch_free(batch);
        }
    }

    last_tokens = tokens;

    auto smpl = llama_sampler_chain_init(llama_sampler_chain_default_params());

    llama_sampler_chain_add(smpl,
                            llama_sampler_init_penalties(512, 1.05f, 0.0f, 0.0f));

    llama_sampler_chain_add(smpl,
                            llama_sampler_init_min_p(0.05f, 1));

    llama_sampler_chain_add(smpl,
                            llama_sampler_init_temp(0.80f));

    llama_sampler_chain_add(smpl,
                            llama_sampler_init_dist(time(NULL)));

    jclass callbackClass = env->GetObjectClass(callback);

    jmethodID onTokenMethod =
            env->GetMethodID(callbackClass, "onToken", "(Ljava/lang/String;)V");

    int n_cur = tokens.size();
    int n_gen = 0;

    auto t_start = std::chrono::high_resolution_clock::now();

    while (n_cur < llama_n_ctx(ctx) && n_gen < 1024) {

        int sampling_idx = (n_gen == 0) ? last_eval_idx : 0;

        llama_token id = llama_sampler_sample(smpl, ctx, sampling_idx);
        llama_sampler_accept(smpl, id);

        bool is_eog = llama_vocab_is_eog(llama_model_get_vocab(model), id);

        if (is_eog) break;

        char piece[128];

        int n_chars =
                llama_token_to_piece(
                        llama_model_get_vocab(model),
                        id,
                        piece,
                        sizeof(piece),
                        0,
                        false);

        if (n_chars > 0) {

            std::string s(piece, n_chars);

            jstring jword = env->NewStringUTF(s.c_str());

            env->CallVoidMethod(callback, onTokenMethod, jword);

            env->DeleteLocalRef(jword);
        }

        last_tokens.push_back(id);

        llama_batch gen_batch = llama_batch_init(1, 0, 1);

        gen_batch.n_tokens = 1;
        gen_batch.token[0] = id;

        gen_batch.pos[0] = n_cur;

        gen_batch.n_seq_id[0] = 1;
        gen_batch.seq_id[0][0] = 0;

        gen_batch.logits[0] = true;

        if (llama_decode(ctx, gen_batch) != 0) {
            LOGE("Token decode failed at %d", n_cur);
            llama_batch_free(gen_batch);
            break;
        }

        llama_batch_free(gen_batch);

        n_cur++;
        n_gen++;
    }

    auto t_end = std::chrono::high_resolution_clock::now();

    auto ms =
            std::chrono::duration_cast<std::chrono::milliseconds>(
                    t_end - t_start).count();

    LOGI("Generation complete: %d tokens in %lld ms (%.2f t/s)",
         n_gen,
         ms,
         (n_gen * 1000.0 / (ms + 1)));

    llama_sampler_free(smpl);
}

extern "C" JNIEXPORT void JNICALL
Java_com_josie_ai_LlamaNative_unload(JNIEnv *env, jobject thiz) {

    if (ctx) llama_free(ctx);
    if (model) llama_model_free(model);

    ctx = nullptr;
    model = nullptr;

    last_tokens.clear();
}