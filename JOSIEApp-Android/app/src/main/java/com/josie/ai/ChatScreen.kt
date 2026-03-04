package com.josie.ai

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.MicOff
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.Image
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import kotlinx.coroutines.launch

@Composable
fun JOSIETheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = Color(0xFFF48FB1), // Accent Pink
            background = Color(0xFF0D0D0D), // Eerie Black
            surface = Color(0xFF1A1A1A)
        ),
        content = content
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(brain: JosieBrain, modelManager: ModelManager, voiceManager: JosieVoiceManager, sttManager: JosieSTTManager) {
    var inputText by remember { mutableStateOf("") }
    val status by brain.status.collectAsState()
    val modelName by brain.currentModelName.collectAsState()
    val progress by modelManager.downloadProgress.collectAsState()
    val downloadStatus by modelManager.downloadStatus.collectAsState()
    val isDownloading by modelManager.isDownloading.collectAsState()
    val transcript by sttManager.transcript.collectAsState()
    val isListening by sttManager.isListening.collectAsState()
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()
    var showModelPicker by remember { mutableStateOf(false) }
    var showVoiceSettings by remember { mutableStateOf(false) }
    
    var pitch by remember { mutableStateOf(voiceManager.pitch) }
    var rate by remember { mutableStateOf(voiceManager.speechRate) }

    // Auto-scroll to bottom on new message
    LaunchedEffect(brain.messages.size) {
        if (brain.messages.isNotEmpty()) {
            listState.animateScrollToItem(brain.messages.size - 1)
        }
    }

    // Sync STT transcript to input text
    LaunchedEffect(transcript) {
        if (transcript.isNotEmpty()) {
            inputText = transcript
        }
    }

    Scaffold(
        topBar = {
            Column(modifier = Modifier.fillMaxWidth().background(Color(0xFF0D0D0D)).padding(16.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Image(
                        painter = painterResource(id = R.drawable.josie_avatar),
                        contentDescription = "JOSIE Avatar",
                        modifier = Modifier
                            .size(64.dp)
                            .clip(CircleShape)
                            .background(Color(0xFF1A1A1A)),
                        contentScale = ContentScale.Crop
                    )
                    Spacer(modifier = Modifier.width(16.dp))
                    Column {
                        Text("J.O.S.I.E.", color = Color(0xFFF48FB1), fontSize = 32.sp)
                        Text("Model: $modelName", color = Color.Gray, fontSize = 12.sp)
                        Text("Assistant: Unfiltered Roleplay", color = Color.DarkGray, fontSize = 10.sp)
                    }
                }
                
                if (isDownloading) {
                    Text(downloadStatus, color = Color.White, fontSize = 12.sp, modifier = Modifier.padding(top = 8.dp))
                    LinearProgressIndicator(
                        progress = { progress },
                        modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
                        color = Color(0xFFF48FB1)
                    )
                }
                
                if (isListening) {
                    Text("JOSIE is listening...", color = Color(0xFFF48FB1), fontSize = 12.sp, modifier = Modifier.padding(top = 8.dp))
                }
            }
        },
        containerColor = Color(0xFF0D0D0D)
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding)) {
            
            LazyColumn(
                state = listState,
                modifier = Modifier.weight(1f).padding(horizontal = 16.dp)
            ) {
                items(brain.messages) { msg ->
                    ChatBubble(msg)
                }
            }
            
            // Interaction Bar
            Row(modifier = Modifier.padding(16.dp).fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = { showModelPicker = true }) {
                    Icon(Icons.Filled.Psychology, contentDescription = "Brain", tint = Color.White)
                }
                
                IconButton(onClick = { showVoiceSettings = true }) {
                    Icon(Icons.Filled.Tune, contentDescription = "Voice Settings", tint = Color.White)
                }

                IconButton(onClick = { 
                    if (isListening) sttManager.stopListening() else sttManager.startListening()
                }) {
                    Icon(
                        if (isListening) Icons.Filled.MicOff else Icons.Filled.Mic, 
                        contentDescription = "Mic", 
                        tint = if (isListening) Color(0xFFF48FB1) else Color.White
                    )
                }
                
                Spacer(modifier = Modifier.width(4.dp))
                
                TextField(
                    value = inputText,
                    onValueChange = { inputText = it },
                    modifier = Modifier.weight(1f),
                    placeholder = { Text("Talk to JOSIE...") },
                    colors = TextFieldDefaults.colors(focusedContainerColor = Color(0xFF1A1A1A), focusedTextColor = Color.White, unfocusedTextColor = Color.White)
                )
                
                Spacer(modifier = Modifier.width(8.dp))
                
                IconButton(
                    onClick = { 
                        brain.sendMessage(inputText, voiceManager)
                        inputText = ""
                    },
                    enabled = status == ModelStatus.READY && inputText.isNotBlank()
                ) {
                    Icon(Icons.Filled.Send, contentDescription = "Send", tint = Color(0xFFF48FB1))
                }
            }
        }
    }

    if (showModelPicker) {
        AlertDialog(
            onDismissRequest = { showModelPicker = false },
            title = { Text("Choose JOSIE's Mind") },
            text = {
                Column {
                    Text(
                        text = "⚠️ Note: Higher parameter counts (B) require more RAM and faster CPUs. 12B models typically need 12GB+ of total system RAM to run smoothly.",
                        color = Color.Gray,
                        fontSize = 12.sp,
                        modifier = Modifier.padding(bottom = 12.dp)
                    )
                    
                    modelManager.getAvailableModels().forEach { model ->
                        TextButton(
                            onClick = {
                                showModelPicker = false
                                scope.launch {
                                    val file = modelManager.downloadModel(model)
                                    if (file != null) {
                                        brain.loadModel(file.absolutePath, model)
                                    }
                                }
                            },
                            modifier = Modifier.fillMaxWidth()
                        ) { 
                            Text(model, color = Color.White) 
                        }
                    }
                }
            },
            confirmButton = {}
        )
    }

    if (showVoiceSettings) {
        AlertDialog(
            onDismissRequest = { showVoiceSettings = false },
            title = { Text("Voice Modulation") },
            text = {
                Column {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("Voice Mode", color = Color.White)
                        Spacer(modifier = Modifier.weight(1f))
                        Switch(
                            checked = voiceManager.isEnabled,
                            onCheckedChange = { voiceManager.isEnabled = it }
                        )
                    }
                    Spacer(modifier = Modifier.height(16.dp))
                    Text("Pitch: ${String.format("%.1f", pitch)}", color = Color.White)
                    Slider(
                        value = pitch,
                        onValueChange = { 
                            pitch = it
                            voiceManager.pitch = it
                        },
                        valueRange = 0.5f..2.0f
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    Text("Rate: ${String.format("%.1f", rate)}", color = Color.White)
                    Slider(
                        value = rate,
                        onValueChange = { 
                            rate = it
                            voiceManager.speechRate = it
                        },
                        valueRange = 0.5f..2.0f
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = { showVoiceSettings = false }) {
                    Text("Done")
                }
            }
        )
    }
}

@Composable
fun ChatBubble(message: ChatMessage) {
    val alignment = if (message.isUser) Alignment.CenterEnd else Alignment.CenterStart
    val bgColor = if (message.isUser) Color(0xFF303F9F) else Color(0xFF262626)

    Box(modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp), contentAlignment = alignment) {
        Row(verticalAlignment = Alignment.Bottom) {
            if (!message.isUser) {
                Image(
                    painter = painterResource(id = R.drawable.josie_avatar),
                    contentDescription = "JOSIE",
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(Color(0xFF1A1A1A)),
                    contentScale = ContentScale.Crop
                )
                Spacer(modifier = Modifier.width(8.dp))
            }
            
            Column(
                modifier = Modifier
                    .background(bgColor, RoundedCornerShape(12.dp))
                    .padding(12.dp)
                    .widthIn(max = 280.dp)
            ) {
                Text(text = message.text, color = Color.White)
            }
        }
    }
}
