import { Routes } from '@angular/router';
import { authGuard } from './core/auth.guard';
import { AdminPageComponent } from './pages/admin/admin';
import { HomePageComponent } from './pages/home/home';
import { LoginComponent } from './pages/login/login';

export const routes: Routes = [
  { path: '', pathMatch: 'full', redirectTo: 'home' },
  { path: 'login', component: LoginComponent, title: 'AURA · entrar' },
  { path: 'home', component: HomePageComponent, canActivate: [authGuard], title: 'AURA · casa' },
  { path: 'admin', component: AdminPageComponent, canActivate: [authGuard], title: 'AURA · operação' },
  { path: '**', redirectTo: 'home' },
];
