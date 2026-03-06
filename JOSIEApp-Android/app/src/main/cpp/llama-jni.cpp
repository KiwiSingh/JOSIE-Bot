#include "llama.h"

#include <algorithm>
#include <android/log.h>
#include <chrono>
#include <cstring>
#include <ctime>
#include <jni.h>
#include <string>
#include <sys/sysinfo.h>
#include <thread>
#include <vector>

#define LOG_TAG "JOSIE_LLAMA"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static llama_model *model = nullptr;
static llama_context *ctx = nullptr;

static std::vector<llama_token> last_tokens;

// ------------------------------------------------
// GPU LAYER DETECTION
// ------------------------------------------------

static int detect_gpu_layers() {

    struct sysinfo info;
    sysinfo(&info);

    long long total_ram = (long long)info.totalram * info.mem_unit;
    long ram_gb = total_ram / (1024LL * 1024LL * 1024LL);

    if (ram_gb >= 12) return 99;
    if (ram_gb >= 8)  return 40;
    if (ram_gb >= 6)  return 24;
    if (ram_gb >= 4)  return 12;

    return 8;
}

// ------------------------------------------------
// LOAD MODEL
// ------------------------------------------------

extern "C" JNIEXPORT jboolean JNICALL
Java_com_josie_ai_LlamaNative_loadModel(JNIEnv *env, jobject,
                                        jstring model_path) {

    const char *path = env->GetStringUTFChars(model_path, nullptr);

    LOGI("Loading model from %s", path);

    llama_backend_init();
    llama_numa_init(GGML_NUMA_STRATEGY_DISABLED);

    auto mparams = llama_model_default_params();

    mparams.n_gpu_layers = detect_gpu_layers();
    mparams.use_mmap = true;
    mparams.use_mlock = false;

    model = llama_model_load_from_file(path, mparams);

    if (!model) {
        LOGE("Model load failed");
        env->ReleaseStringUTFChars(model_path, path);
        return JNI_FALSE;
    }

    auto cparams = llama_context_default_params();

    // Vulkan-friendly settings
    cparams.n_ctx = 1024;
    cparams.n_batch = 256;
    cparams.n_ubatch = 256;

    // Offload KV cache
    cparams.offload_kqv = true;

    unsigned int cores = std::thread::hardware_concurrency();

    cparams.n_threads = std::max(2u, cores / 2);
    cparams.n_threads_batch = std::max(2u, cores - 1);

    LOGI("Context: ctx=%d gpu_layers=%d threads=%d/%d",
         cparams.n_ctx,
         mparams.n_gpu_layers,
         cparams.n_threads,
         cparams.n_threads_batch);

    ctx = llama_init_from_model(model, cparams);

    env->ReleaseStringUTFChars(model_path, path);

    return ctx != nullptr ? JNI_TRUE : JNI_FALSE;
}

// ------------------------------------------------
// GENERATION
// ------------------------------------------------

extern "C" JNIEXPORT void JNICALL
Java_com_josie_ai_LlamaNative_generateStream(JNIEnv *env, jobject,
                                             jstring prompt,
                                             jobject callback) {

    if (!ctx || !model) {
        LOGE("Model not initialized");
        return;
    }

    const char *p_str = env->GetStringUTFChars(prompt, nullptr);

    int p_bytes = strlen(p_str);

    std::vector<llama_token> tokens(p_bytes + 4);

    int n_tokens = llama_tokenize(
        llama_model_get_vocab(model),
        p_str,
        p_bytes,
        tokens.data(),
        tokens.size(),
        true,
        true);

    env->ReleaseStringUTFChars(prompt, p_str);

    if (n_tokens < 0) {
        LOGE("Tokenization failed");
        return;
    }

    tokens.resize(n_tokens);

    if (tokens.size() > (size_t)llama_n_ctx(ctx)) {
        LOGE("Prompt too long");
        return;
    }

    // -------- PREFIX CACHE --------

    int n_keep = 0;

    for (size_t i = 0; i < std::min(tokens.size(), last_tokens.size()); i++) {
        if (tokens[i] != last_tokens[i])
            break;
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

    LOGI("Prompt tokens=%zu cached=%d new=%d",
         tokens.size(), n_keep, n_decode);

    const int chunk_size = 256;

    llama_batch batch = llama_batch_init(chunk_size, 0, 1);

    int last_eval_idx = 0;

    for (int i = 0; i < n_decode; i += chunk_size) {

        int n_eval = std::min(chunk_size, n_decode - i);

        batch.n_tokens = n_eval;

        for (int j = 0; j < n_eval; j++) {

            batch.token[j] = tokens[n_past + i + j];
            batch.pos[j] = n_past + i + j;

            batch.n_seq_id[j] = 1;
            batch.seq_id[j][0] = 0;

            batch.logits[j] = (i + j == n_decode - 1);
        }

        if (llama_decode(ctx, batch) != 0) {
            LOGE("Decode failure");
            last_tokens.clear();
            llama_batch_free(batch);
            return;
        }

        last_eval_idx = n_eval - 1;
    }

    last_tokens = tokens;

    llama_batch_free(batch);

    // -------- SAMPLER --------

    auto smpl =
        llama_sampler_chain_init(llama_sampler_chain_default_params());

    llama_sampler_chain_add(
        smpl,
        llama_sampler_init_penalties(512, 1.05f, 0.0f, 0.0f));

    llama_sampler_chain_add(
        smpl,
        llama_sampler_init_min_p(0.05f, 1));

    llama_sampler_chain_add(
        smpl,
        llama_sampler_init_temp(0.85f));

    llama_sampler_chain_add(
        smpl,
        llama_sampler_init_top_k(40));

    llama_sampler_chain_add(
        smpl,
        llama_sampler_init_top_p(0.9f, 1));

    llama_sampler_chain_add(
        smpl,
        llama_sampler_init_dist(time(NULL)));

    jclass cb = env->GetObjectClass(callback);

    jmethodID onToken =
        env->GetMethodID(cb, "onToken", "([B)V");

    int n_cur = tokens.size();
    int n_gen = 0;

    const int max_gen = 2048;

    auto start = std::chrono::high_resolution_clock::now();

    while (n_cur < llama_n_ctx(ctx) && n_gen < max_gen) {

        int sampling_idx = (n_gen == 0) ? last_eval_idx : 0;

        llama_token id =
            llama_sampler_sample(smpl, ctx, sampling_idx);

        llama_sampler_accept(smpl, id);

        if (llama_vocab_is_eog(llama_model_get_vocab(model), id))
            break;

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

            jbyteArray jbytes = env->NewByteArray(n_chars);

            env->SetByteArrayRegion(
                jbytes, 0, n_chars,
                reinterpret_cast<const jbyte *>(piece));

            env->CallVoidMethod(callback, onToken, jbytes);

            env->DeleteLocalRef(jbytes);
        }

        last_tokens.push_back(id);

        llama_batch gen = llama_batch_init(1, 0, 1);

        gen.n_tokens = 1;
        gen.token[0] = id;
        gen.pos[0] = n_cur;

        gen.n_seq_id[0] = 1;
        gen.seq_id[0][0] = 0;

        gen.logits[0] = true;

        if (llama_decode(ctx, gen) != 0) {
            LOGE("Token decode failure");
            llama_batch_free(gen);
            break;
        }

        llama_batch_free(gen);

        n_cur++;
        n_gen++;
    }

    auto end = std::chrono::high_resolution_clock::now();

    auto ms =
        std::chrono::duration_cast<std::chrono::milliseconds>(end - start)
            .count();

    LOGI("Generated %d tokens in %lld ms (%.2f t/s)",
         n_gen,
         ms,
         (n_gen * 1000.0 / (ms + 1)));

    llama_sampler_free(smpl);
}

// ------------------------------------------------
// UNLOAD
// ------------------------------------------------

extern "C" JNIEXPORT void JNICALL
Java_com_josie_ai_LlamaNative_unload(JNIEnv *, jobject) {

    if (ctx)
        llama_free(ctx);

    if (model)
        llama_model_free(model);

    ctx = nullptr;
    model = nullptr;

    last_tokens.clear();
}