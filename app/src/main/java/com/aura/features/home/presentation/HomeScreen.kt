package com.aura.features.home.presentation

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.hilt.navigation.compose.hiltViewModel
import com.aura.R
import com.aura.features.home.domain.TranscriptMessage

private val HomePrimary = Color(0xFF2B6EA0)
private val HomeAccent = Color(0xFFE53935)
private val HomeNavyText = Color(0xFF0F2638)
private val HomeGreyText = Color(0xFF6B7785)
private val HomeSuggestionsBg = Color(0xFFE8F4FD)
private val HomeSuggestionsText = Color(0xFF1A4468)
private val HomeDivider = Color(0xFFBFD4E8)
@Composable
fun HomeScreen(viewModel: HomeViewModel = hiltViewModel()) {
    val state by viewModel.viewState.collectAsStateWithLifecycle()

    when (val current = state) {
        HomeScreenViewState.Loading -> LoadingScreen()
        HomeScreenViewState.Error -> ErrorScreen(onRetry = viewModel::onRetry)
        is HomeScreenViewState.Success -> SuccessContent(
            state = current,
            onMicTapped = viewModel::onMicTapped,
        )
    }
}

@Composable
private fun LoadingScreen() {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.White),
        contentAlignment = Alignment.Center
    ) {
        CircularProgressIndicator(color = HomePrimary)
    }
}

@Composable
private fun ErrorScreen(onRetry: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.White)
            .padding(32.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = "Algo deu errado",
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = HomeNavyText,
            )
            Spacer(modifier = Modifier.height(16.dp))
            Button(
                onClick = onRetry,
                colors = ButtonDefaults.buttonColors(containerColor = HomePrimary),
            ) {
                Text(text = "Tentar novamente", color = Color.White)
            }
        }
    }
}

@Composable
private fun SuccessContent(
    state: HomeScreenViewState.Success,
    onMicTapped: (android.content.Context) -> Unit,
) {
    val context = LocalContext.current

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) onMicTapped(context)
    }

    val scrollState = rememberScrollState()
    LaunchedEffect(state.transcript.size) {
        scrollState.animateScrollTo(scrollState.maxValue)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.White)
            .statusBarsPadding()
            .verticalScroll(scrollState),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.height(32.dp))
        Image(
            painter = painterResource(R.drawable.ic_aura_logo),
            contentDescription = null,
            modifier = Modifier
                .width(128.dp)
                .height(128.dp),
            contentScale = ContentScale.Fit
        )
        Spacer(Modifier.height(32.dp))
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 32.dp)
        ) {
            Text(
                text = "Olá, ${state.name}",
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = HomeNavyText
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "Como posso te ajudar?",
                fontSize = 18.sp,
                fontWeight = FontWeight.Normal,
                color = HomeGreyText
            )
        }
        Spacer(Modifier.height(16.dp))
        MicButton(
            voice = state.voice,
            onClick = {
                val granted = ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.RECORD_AUDIO,
                ) == PackageManager.PERMISSION_GRANTED
                if (granted) {
                    onMicTapped(context)
                } else {
                    permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                }
            }
        )
        if (state.transcript.isNotEmpty()) {
            Spacer(Modifier.height(24.dp))
            TranscriptSection(
                messages = state.transcript,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
            )
        }
        Spacer(Modifier.height(16.dp))
    }
}

@Composable
private fun MicButton(voice: VoiceUiState, onClick: () -> Unit) {
    val backgroundColor = when (voice) {
        VoiceUiState.Listening, VoiceUiState.Speaking, VoiceUiState.Connecting -> HomeAccent
        VoiceUiState.Idle, is VoiceUiState.Error -> HomePrimary
    }
    val icon: ImageVector = when (voice) {
        VoiceUiState.Listening, VoiceUiState.Speaking, VoiceUiState.Connecting -> Icons.Filled.Stop
        VoiceUiState.Idle, is VoiceUiState.Error -> Icons.Filled.Mic
    }
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            modifier = Modifier
                .size(96.dp)
                .clip(CircleShape)
                .background(backgroundColor)
                .clickable(onClick = onClick),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = icon,
                contentDescription = "Microfone",
                tint = Color.White,
                modifier = Modifier.size(36.dp)
            )
        }
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = voice.statusLabel(),
            fontSize = 24.sp,
            fontWeight = FontWeight(600),
            color = voice.statusColor()
        )
    }
}

private fun VoiceUiState.statusLabel(): String = when (this) {
    VoiceUiState.Idle -> "Toque para falar"
    VoiceUiState.Connecting -> "Conectando…"
    VoiceUiState.Listening -> "Ouvindo…"
    VoiceUiState.Speaking -> "Falando…"
    is VoiceUiState.Error -> message
}

private fun VoiceUiState.statusColor(): Color = when (this) {
    is VoiceUiState.Error -> HomeAccent
    else -> HomePrimary
}

@Composable
private fun TranscriptSection(
    messages: List<TranscriptMessage>,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        messages.forEach { message ->
            TranscriptBubble(message)
        }
    }
}

@Composable
private fun TranscriptBubble(message: TranscriptMessage) {
    val bubbleColor = if (message.isUser) HomePrimary else HomeSuggestionsBg
    val textColor = if (message.isUser) Color.White else HomeNavyText
    val shape = if (message.isUser) {
        RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp, bottomStart = 16.dp, bottomEnd = 4.dp)
    } else {
        RoundedCornerShape(topStart = 4.dp, topEnd = 16.dp, bottomStart = 16.dp, bottomEnd = 16.dp)
    }

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = if (message.isUser) Arrangement.End else Arrangement.Start,
    ) {
        Box(
            modifier = Modifier
                .widthIn(max = 280.dp)
                .background(color = bubbleColor, shape = shape)
                .padding(horizontal = 14.dp, vertical = 10.dp)
        ) {
            Text(text = message.text, fontSize = 15.sp, color = textColor)
        }
    }
}

@Composable
private fun SuggestionsCard(modifier: Modifier = Modifier) {
    val suggestions = listOf(
        "“Registrar sintoma”",
        "“Confirmar medicamento”",
        "“Preciso de ajuda”"
    )

    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(16.dp),
        color = HomeSuggestionsBg
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            suggestions.forEachIndexed { index, suggestion ->
                if (index > 0) {
                    HorizontalDivider(
                        modifier = Modifier.padding(vertical = 8.dp),
                        color = HomeDivider,
                        thickness = 1.dp
                    )
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = "•",
                        fontSize = 14.sp,
                        color = HomeSuggestionsText
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = suggestion,
                        fontSize = 14.sp,
                        color = HomeSuggestionsText
                    )
                }
            }
        }
    }
}

