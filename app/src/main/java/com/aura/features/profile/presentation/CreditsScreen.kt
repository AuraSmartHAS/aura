package com.aura.features.profile.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private val CreditsNavyText = Color(0xFF0F2638)
private val CreditsGreyText = Color(0xFF6B7785)
private val CreditsBorder = Color(0xFFDDE3EA)

private data class Developer(val name: String, val rm: String)

private val developers = listOf(
    Developer("Vinícius Miranda Baptista", "RM 555081"),
    Developer("João Domingos Góes Filho", "RM 564465"),
    Developer("Pedro Henrique Arenas Negri", "RM 554971"),
    Developer("Júlia Alves Dias", "RM 557151"),
    Developer("Frederico Enrique Garcia da Silva Passos", "RM 550532"),
)

@Composable
fun CreditsScreen(onNavigateBack: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(ProfileBg)
            .statusBarsPadding(),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(Color.White)
                .padding(end = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onNavigateBack) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Voltar",
                    tint = CreditsNavyText,
                )
            }
            Text(
                text = "Créditos",
                fontSize = 18.sp,
                fontWeight = FontWeight.SemiBold,
                color = CreditsNavyText,
            )
        }

        Spacer(Modifier.height(24.dp))

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .background(Color.White, RoundedCornerShape(12.dp)),
        ) {
            developers.forEachIndexed { index, developer ->
                if (index > 0) {
                    HorizontalDivider(
                        modifier = Modifier.padding(horizontal = 16.dp),
                        color = CreditsBorder,
                    )
                }
                DeveloperItem(developer)
            }
        }
    }
}

@Composable
private fun DeveloperItem(developer: Developer) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 14.dp),
    ) {
        Text(
            text = developer.name,
            fontSize = 15.sp,
            fontWeight = FontWeight.Medium,
            color = CreditsNavyText,
        )
        Spacer(Modifier.height(2.dp))
        Text(
            text = developer.rm,
            fontSize = 13.sp,
            color = CreditsGreyText,
        )
    }
}
