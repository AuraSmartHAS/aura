package com.aura.navigation

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import com.aura.features.home.presentation.HomeScreen
import com.aura.features.profile.presentation.ProfileScreen

private val NavPrimary = Color(0xFF2B6EA0)
private val NavUnselected = Color(0xFF475569)
private val NavIndicator = Color(0xFFE8F4FD)

private enum class MainTab { Home, Profile }

@Composable
private fun navItemColors() = NavigationBarItemDefaults.colors(
    selectedIconColor = NavPrimary,
    selectedTextColor = NavPrimary,
    indicatorColor = NavIndicator,
    unselectedIconColor = NavUnselected,
    unselectedTextColor = NavUnselected,
)

@Composable
fun MainScreen(onNavigateToCredits: () -> Unit) {
    var selectedTab by rememberSaveable { mutableStateOf(MainTab.Home) }

    Column(modifier = Modifier.fillMaxSize()) {
        Box(modifier = Modifier.weight(1f)) {
            when (selectedTab) {
                MainTab.Home -> HomeScreen()
                MainTab.Profile -> ProfileScreen(onNavigateToCredits = onNavigateToCredits)
            }
        }
        NavigationBar(containerColor = Color.White) {
            NavigationBarItem(
                selected = selectedTab == MainTab.Home,
                onClick = { selectedTab = MainTab.Home },
                icon = { Icon(Icons.Outlined.Home, contentDescription = "Início") },
                label = { Text("Início") },
                colors = navItemColors()
            )
            NavigationBarItem(
                selected = selectedTab == MainTab.Profile,
                onClick = { selectedTab = MainTab.Profile },
                icon = { Icon(Icons.Outlined.Person, contentDescription = "Perfil") },
                label = { Text("Perfil") },
                colors = navItemColors()
            )
        }
    }
}
