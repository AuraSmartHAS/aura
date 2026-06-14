package com.aura.features.auth.presentation

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

internal val AuraPrimary = Color(0xFF2B6EA0)
internal val AuraTextPrimary = Color(0xFF0F172A)
internal val AuraTextSecondary = Color(0xFF475569)
internal val AuraHint = Color(0xFF6B7785)
internal val AuraLink = Color(0xFF3A8FCC)
internal val AuraBorder = Color(0xFFDDE3EA)
internal val AuraFieldShape = RoundedCornerShape(8.dp)

@Composable
internal fun auraFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedBorderColor = AuraPrimary,
    unfocusedBorderColor = AuraBorder,
    cursorColor = AuraPrimary,
    focusedContainerColor = Color.White,
    unfocusedContainerColor = Color.White,
    errorContainerColor = Color.White,
)
