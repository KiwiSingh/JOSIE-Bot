package com.josie.ai

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.FileOutputStream

class ModelManager(private val context: Context) {
    val downloadProgress = MutableStateFlow(0f)
    val downloadStatus = MutableStateFlow("")
    val isDownloading = MutableStateFlow(false)

    // Recommended Unfiltered GGUF URLs
    private val modelUrls = mapOf(
        "Stheno-8B (Elite RP)" to "https://huggingface.co/mradermacher/L3-8B-Stheno-v3.2-GGUF/resolve/main/L3-8B-Stheno-v3.2.Q4_K_M.gguf",
        "Violet-Lotus-12B (Extreme)" to "https://huggingface.co/mradermacher/MN-Violet-Lotus-12B-GGUF/resolve/main/MN-Violet-Lotus-12B.Q4_K_M.gguf",
        "Gemma-3-4B (Uncensored RP)" to "https://huggingface.co/mradermacher/gemma-3-4b-it-uncensored-GGUF/resolve/main/gemma-3-4b-it-uncensored.Q4_K_M.gguf",
        "Phi-3.5-Mini (3.8B - Fast)" to "https://huggingface.co/mradermacher/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct.Q4_K_M.gguf"
    )

    fun getAvailableModels() = modelUrls.keys.toList()

    suspend fun downloadModel(modelName: String): File? = withContext(Dispatchers.IO) {
        val url = modelUrls[modelName] ?: return@withContext null
        val fileName = "$modelName.gguf"
        val destination = File(context.filesDir, "models/$fileName")
        
        if (destination.exists()) return@withContext destination
        destination.parentFile?.mkdirs()

        isDownloading.value = true
        val client = OkHttpClient.Builder()
            .connectTimeout(60, java.util.concurrent.TimeUnit.SECONDS)
            .readTimeout(0, java.util.concurrent.TimeUnit.SECONDS) // Infinite timeout for long downloads
            .writeTimeout(60, java.util.concurrent.TimeUnit.SECONDS)
            .build()
        val request = Request.Builder().url(url).build()
        
        try {
            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) return@withContext null
                
                val body = response.body ?: return@withContext null
                val totalBytes = body.contentLength()
                var bytesRead = 0L
                var lastTime = System.currentTimeMillis()
                var lastBytes = 0L
                
                body.byteStream().use { input ->
                    FileOutputStream(destination).use { output ->
                        val buffer = ByteArray(8 * 1024)
                        var read: Int
                        while (input.read(buffer).also { read = it } != -1) {
                            output.write(buffer, 0, read)
                            bytesRead += read
                            
                            val currentTime = System.currentTimeMillis()
                            if (currentTime - lastTime >= 500) { // Update every 500ms
                                val speed = (bytesRead - lastBytes).toFloat() / (currentTime - lastTime) * 1000 / 1024 / 1024 // MB/s
                                if (totalBytes > 0) {
                                    downloadProgress.value = bytesRead.toFloat() / totalBytes
                                    downloadStatus.value = String.format("Downloading: %.1f/%.1f GB (%.1f MB/s)", 
                                        bytesRead / (1024f*1024f*1024f), 
                                        totalBytes / (1024f*1024f*1024f),
                                        speed)
                                }
                                lastTime = currentTime
                                lastBytes = bytesRead
                            }
                        }
                    }
                }
            }
            return@withContext destination
        } catch (e: Exception) {
            destination.delete()
            return@withContext null
        } finally {
            isDownloading.value = false
            downloadProgress.value = 0f
        }
    }
}
