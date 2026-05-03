package com.aura.navigation

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.aura.features.auth.presentation.LoginScreen
import com.aura.features.auth.presentation.SignupScreen
import com.aura.features.home.presentation.HomeScreen
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.status.SessionStatus

private object Routes {
    const val LOGIN = "login"
    const val SIGNUP = "signup"
    const val HOME = "home"
}

@Composable
fun AppNavigation(supabaseClient: SupabaseClient) {
    val sessionStatus by supabaseClient.auth.sessionStatus.collectAsState()

    when (sessionStatus) {
        is SessionStatus.Initializing -> {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
        }
        else -> {
            val startDestination = if (sessionStatus is SessionStatus.Authenticated) {
                Routes.HOME
            } else {
                Routes.LOGIN
            }
            AppNavHost(startDestination = startDestination)
        }
    }
}

@Composable
private fun AppNavHost(startDestination: String) {
    val navController = rememberNavController()

    NavHost(navController = navController, startDestination = startDestination) {
        composable(Routes.LOGIN) {
            LoginScreen(
                onLoginSuccess = {
                    navController.navigate(Routes.HOME) {
                        popUpTo(Routes.LOGIN) { inclusive = true }
                    }
                },
                onNavigateToSignup = {
                    navController.navigate(Routes.SIGNUP)
                }
            )
        }
        composable(Routes.SIGNUP) {
            SignupScreen(
                onSignupSuccess = {
                    navController.navigate(Routes.HOME) {
                        popUpTo(Routes.LOGIN) { inclusive = true }
                    }
                },
                onNavigateToLogin = {
                    navController.popBackStack()
                }
            )
        }
        composable(Routes.HOME) {
            HomeScreen()
        }
    }
}
