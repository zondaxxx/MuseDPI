package io.github.romanvht.byedpi.palka.ui

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.text.format.Formatter
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoFixHigh
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material.icons.rounded.Error
import androidx.compose.material.icons.rounded.HourglassTop
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.PowerSettingsNew
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.SwapVerticalCircle
import androidx.compose.material.icons.rounded.Terminal
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material.icons.rounded.VerifiedUser
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.github.romanvht.byedpi.R
import io.github.romanvht.byedpi.data.Mode
import io.github.romanvht.byedpi.palka.Palka
import io.github.romanvht.byedpi.palka.PalkaAutomation
import io.github.romanvht.byedpi.palka.PalkaDiagnostics
import io.github.romanvht.byedpi.palka.PalkaProbeStatus
import io.github.romanvht.byedpi.palka.PalkaServiceProbe
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import kotlinx.coroutines.delay

@Composable
fun HomeScreen() {
    val nav = LocalNavigator.current
    val host = LocalHost.current
    val context = LocalContext.current
    val running = Palka.vpnRunning
    var actionInFlight by remember { mutableStateOf(false) }

    val lifecycle = LocalLifecycleOwner.current.lifecycle
    // Status + counters: broadcasts update Palka, this keeps the tunnel line live
    // while the screen is visible (not in the background).
    LaunchedEffect(running) {
        actionInFlight = false
        lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
            while (true) {
                Palka.refreshTunnelStats()
                delay(1000)
            }
        }
    }
    // Refresh the service ping on open and a moment after each connect/disconnect.
    LaunchedEffect(running) {
        PalkaDiagnostics.ensureIdle()
        delay(if (running) 1200 else 300)
        PalkaDiagnostics.refresh(includeBulk = false) { PalkaAutomation.evaluateRecovery(it) }
    }
    // Smart recovery check every two minutes while connected and on screen (as on iOS,
    // never in the background: probes cost battery and a paused app cannot act on them).
    LaunchedEffect(running) {
        if (!running) return@LaunchedEffect
        lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) {
            while (true) {
                delay(120_000)
                if (Palka.smartRecovery && !PalkaAutomation.isRunning && !PalkaDiagnostics.isRefreshing) {
                    PalkaDiagnostics.refresh(attempts = 2, includeBulk = false) { PalkaAutomation.evaluateRecovery(it) }
                }
            }
        }
    }

    val openSettings = {
        if (running) host.alert(context.getString(R.string.palka_settings_locked), null)
        else nav.push(PalkaRoute.Settings)
    }

    PalkaScaffold(title = null, spacing = PalkaDesign.sectionSpacing) {
        Box(Modifier.palkaEntrance()) { Header(running, openSettings) }
        Box(Modifier.palkaEntrance(50)) {
            ConnectionCard(running, actionInFlight || PalkaAutomation.isRunning) {
                if (actionInFlight) return@ConnectionCard
                actionInFlight = true
                if (running) host.disconnect() else host.connect()
            }
        }
        LaunchedEffect(actionInFlight) {
            if (actionInFlight) {
                delay(8000)
                actionInFlight = false
            }
        }
        PalkaAutomation.recoverySuggestion?.let { suggestion ->
            Box(Modifier.palkaEntrance(80)) { RecoveryCard(suggestion.name) }
        }
        Box(Modifier.palkaEntrance(100)) { SmartSetupCard { nav.push(PalkaRoute.Automation) } }
        Box(Modifier.palkaEntrance(150)) { ServiceLatencyCard { nav.push(PalkaRoute.Diagnostics) } }
        Box(Modifier.palkaEntrance(200)) { PresetCard() }
        Box(Modifier.palkaEntrance(250)) { SettingsControl(running, openSettings) }
        Box(Modifier.palkaEntrance(300)) { RuntimeLogCard(running) }
    }
}

@Composable
private fun Header(running: Boolean, onSettings: () -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
        Image(
            painterResource(R.drawable.palka_app_icon), null,
            modifier = Modifier
                .size(44.dp)
                .clip(RoundedCornerShape(13.dp))
                .border(1.dp, Color.White.copy(alpha = 0.10f), RoundedCornerShape(13.dp))
        )
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(stringResource(R.string.palka_title), style = palkaText(30.sp, FontWeight.Black, tracking = (-1.1).sp))
            Text(stringResource(R.string.palka_subtitle), style = palkaText(14.sp, color = PalkaDesign.textSecondary))
        }
        Box(
            Modifier
                .size(46.dp)
                .palkaPressable(onClick = onSettings)
                .clip(CircleShape)
                .background(Color.White.copy(alpha = 0.06f))
                .border(1.dp, PalkaDesign.border, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                if (running) Icons.Rounded.Lock else Icons.Rounded.Tune,
                stringResource(R.string.palka_general_settings),
                tint = PalkaDesign.textSecondary,
                modifier = Modifier.size(19.dp)
            )
        }
    }
}

@Composable
private fun ConnectionCard(running: Boolean, inFlight: Boolean, onToggle: () -> Unit) {
    Column(
        Modifier.fillMaxWidth().palkaCard(24.dp, selected = running).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            PalkaStatusDot(running)
            Text(
                stringResource(if (running) R.string.palka_status_active else R.string.palka_status_inactive),
                style = palkaText(12.sp, FontWeight.SemiBold, if (running) PalkaDesign.successText else PalkaDesign.textMuted, tracking = 0.45.sp),
                modifier = Modifier.weight(1f)
            )
            PalkaTag(if (running) "ON" else "OFF", mono = true)
        }
        Column(verticalArrangement = Arrangement.spacedBy(9.dp)) {
            Text(
                stringResource(if (running) R.string.palka_protection_on_title else R.string.palka_protection_off_title),
                style = palkaText(26.sp, FontWeight.Bold, tracking = (-0.5).sp, lineHeight = 30.sp)
            )
            Text(
                stringResource(if (running) R.string.palka_protection_on_description else R.string.palka_protection_off_description),
                style = palkaText(14.sp, color = PalkaDesign.textSecondary, lineHeight = 20.sp)
            )
        }
        PalkaPrimaryButton(onClick = onToggle, enabled = !inFlight) {
            if (inFlight) PalkaSpinner(Color.Black.copy(alpha = 0.78f))
            else Icon(Icons.Rounded.PowerSettingsNew, null, modifier = Modifier.size(19.dp))
            Text(
                stringResource(
                    when {
                        inFlight -> R.string.palka_please_wait
                        running -> R.string.palka_disconnect
                        else -> R.string.palka_connect
                    }
                )
            )
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Metric(stringResource(R.string.palka_local_core), stringResource(R.string.palka_on_device), Modifier.weight(1f))
            Box(Modifier.padding(horizontal = 16.dp).width(1.dp).height(34.dp).background(Color.White.copy(alpha = 0.08f)))
            Metric(
                if (Palka.mode == Mode.VPN) stringResource(R.string.palka_local_proxy) else "SOCKS5",
                Palka.proxyAddress, Modifier.weight(1f), mono = true
            )
        }
        if (running) TunnelTrafficLine()
    }
}

@Composable
private fun Metric(title: String, value: String, modifier: Modifier, mono: Boolean = false) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(title.uppercase(), style = palkaText(10.sp, FontWeight.SemiBold, PalkaDesign.textMuted, tracking = 0.55.sp))
        Text(value, style = palkaText(12.sp, FontWeight.SemiBold, mono = mono), maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun TunnelTrafficLine() {
    val context = LocalContext.current
    val stats = Palka.tunnelStats
    val proxyMode = Palka.runningMode == Mode.Proxy
    val hasPackets = proxyMode || (stats?.totalPackets ?: 0) > 0
    val text = when {
        proxyMode -> stringResource(R.string.palka_tunnel_proxy_mode)
        stats == null -> stringResource(R.string.palka_tunnel_checking)
        stats.totalPackets == 0L -> stringResource(R.string.palka_tunnel_no_packets)
        else -> "↑ ${Formatter.formatShortFileSize(context, stats.upBytes)} · ↓ ${Formatter.formatShortFileSize(context, stats.downBytes)} · ${stats.totalPackets} pkt"
    }
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Color.White.copy(alpha = 0.045f)).padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Icon(
            if (hasPackets) Icons.Rounded.SwapVerticalCircle else Icons.Rounded.Error, null,
            tint = if (hasPackets) PalkaDesign.successText else PalkaDesign.errorText,
            modifier = Modifier.size(20.dp)
        )
        Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(stringResource(R.string.palka_tunnel_traffic), style = palkaText(10.sp, FontWeight.SemiBold, PalkaDesign.textMuted, tracking = 0.45.sp))
            Text(text, style = palkaText(12.sp, FontWeight.SemiBold, mono = !proxyMode))
        }
    }
}

@Composable
private fun RecoveryCard(name: String) {
    Column(
        Modifier.fillMaxWidth().palkaCard(selected = true).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(stringResource(R.string.palka_recovery_suggestion_title), style = palkaText(15.sp, FontWeight.Bold))
        Text(stringResource(R.string.palka_recovery_suggestion_format, name), style = palkaText(12.sp, color = PalkaDesign.textSecondary))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
            PalkaCompactPrimaryButton(stringResource(R.string.palka_recovery_switch), PalkaAutomation::acceptRecoverySuggestion)
            PalkaSecondaryButton(PalkaAutomation::dismissRecoverySuggestion, Modifier.weight(1f)) {
                Text(stringResource(R.string.palka_recovery_dismiss))
            }
        }
    }
}

@Composable
private fun SmartSetupCard(onOpen: () -> Unit) {
    val running = PalkaAutomation.isRunning
    Row(
        Modifier.fillMaxWidth().palkaPressable(onClick = onOpen).palkaCard(selected = running).padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        PalkaIconTile(if (running) Icons.Rounded.HourglassTop else Icons.Rounded.AutoFixHigh)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(stringResource(R.string.palka_auto_title), style = palkaText(15.sp, FontWeight.Bold))
            Text(
                if (running) PalkaAutomation.currentStrategyName else stringResource(R.string.palka_auto_home_description),
                style = palkaText(12.sp, color = PalkaDesign.textSecondary), maxLines = 2
            )
        }
        Icon(Icons.Rounded.ChevronRight, null, tint = PalkaDesign.textDim, modifier = Modifier.size(18.dp))
    }
}

@Composable
private fun ServiceLatencyCard(onDetails: () -> Unit) {
    Column(
        Modifier.fillMaxWidth().palkaCard().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(stringResource(R.string.palka_service_ping_title), style = palkaText(16.sp, FontWeight.Bold))
                Text(stringResource(R.string.palka_service_ping_description), style = palkaText(11.sp, color = PalkaDesign.textMuted))
            }
            PalkaCircleButton(
                onClick = { PalkaDiagnostics.refresh(includeBulk = false) { PalkaAutomation.evaluateRecovery(it) } },
                enabled = !PalkaDiagnostics.isRefreshing && !PalkaAutomation.isRunning,
                contentDescription = stringResource(R.string.palka_service_ping_refresh)
            ) {
                if (PalkaDiagnostics.isRefreshing) PalkaSpinner()
                else Icon(Icons.Rounded.Refresh, null, tint = PalkaDesign.textPrimary, modifier = Modifier.size(18.dp))
            }
        }
        PalkaDiagnostics.services.forEach { ServiceLatencyRow(it) }
        PalkaDiagnostics.services.mapNotNull { it.checkedAt }.maxOrNull()?.let { checkedAt ->
            val time = android.text.format.DateFormat.getTimeFormat(LocalContext.current)
                .format(java.util.Date(checkedAt))
            Text(
                "${stringResource(R.string.palka_last_checked)} $time",
                style = palkaText(11.sp, color = PalkaDesign.textMuted)
            )
        }
        Box(
            Modifier.fillMaxWidth().heightIn(min = 44.dp).palkaPressable(onClick = onDetails),
            contentAlignment = Alignment.Center
        ) {
            Text(stringResource(R.string.palka_diagnostics_details), style = palkaText(12.sp, FontWeight.SemiBold, PalkaDesign.textSecondary))
        }
    }
}

@Composable
private fun ServiceLatencyRow(service: PalkaServiceProbe) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 44.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            Modifier.size(40.dp).clip(RoundedCornerShape(11.dp)).background(Color.White.copy(alpha = 0.06f)),
            contentAlignment = Alignment.Center
        ) {
            Text(service.name.take(1), style = palkaText(14.sp, FontWeight.Bold))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(service.name, style = palkaText(14.sp, FontWeight.SemiBold), maxLines = 1, overflow = TextOverflow.Ellipsis)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                val color = serviceStatusColor(service.status)
                Box(
                    Modifier
                        .size(7.dp)
                        .then(
                            if (service.status == PalkaProbeStatus.Reachable)
                                Modifier.shadow(4.dp, CircleShape, spotColor = PalkaDesign.success, ambientColor = PalkaDesign.success)
                            else Modifier
                        )
                        .background(color, CircleShape)
                )
                Text(serviceStatusText(service.status), style = palkaText(11.sp, color = PalkaDesign.textMuted))
            }
        }
        Text(
            service.latencyMs?.let { "$it ms" } ?: "—",
            style = palkaText(
                14.sp, FontWeight.SemiBold,
                if (service.status == PalkaProbeStatus.Reachable) PalkaDesign.textPrimary else PalkaDesign.textMuted,
                mono = true
            )
        )
    }
}

@Composable
fun serviceStatusText(status: PalkaProbeStatus): String = stringResource(
    when (status) {
        PalkaProbeStatus.Idle -> R.string.palka_service_ping_idle
        PalkaProbeStatus.Testing -> R.string.palka_service_ping_testing
        PalkaProbeStatus.Reachable -> R.string.palka_service_ping_available
        PalkaProbeStatus.Partial -> R.string.palka_diagnostics_partial
        PalkaProbeStatus.Unavailable -> R.string.palka_service_ping_unavailable
    }
)

fun serviceStatusColor(status: PalkaProbeStatus): Color = when (status) {
    PalkaProbeStatus.Reachable -> PalkaDesign.success
    PalkaProbeStatus.Partial -> PalkaDesign.warning
    PalkaProbeStatus.Unavailable -> PalkaDesign.errorText
    PalkaProbeStatus.Idle, PalkaProbeStatus.Testing -> PalkaDesign.textDim
}

@Composable
private fun PresetCard() {
    Row(
        Modifier.fillMaxWidth().palkaCard(selected = true).padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        PalkaIconTile(Icons.Rounded.VerifiedUser)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(stringResource(R.string.palka_active_preset).uppercase(), style = palkaText(10.sp, FontWeight.SemiBold, PalkaDesign.textMuted, tracking = 0.55.sp))
            Text(Palka.activeStrategyName.ifBlank { "—" }, style = palkaText(15.sp, FontWeight.Bold))
            Text(stringResource(R.string.palka_preset_scope), style = palkaText(12.sp, color = PalkaDesign.textSecondary))
        }
    }
}

@Composable
private fun SettingsControl(running: Boolean, onOpen: () -> Unit) {
    PalkaSecondaryButton(onClick = onOpen) {
        if (running) {
            Icon(Icons.Rounded.Lock, null, modifier = Modifier.size(18.dp))
            Text(stringResource(R.string.palka_settings_locked))
        } else {
            Icon(Icons.Rounded.Tune, null, modifier = Modifier.size(18.dp))
            Text(stringResource(R.string.palka_general_settings), modifier = Modifier.weight(1f))
            Icon(Icons.Rounded.ChevronRight, null, tint = PalkaDesign.textMuted, modifier = Modifier.size(16.dp))
        }
    }
}

@Composable
private fun RuntimeLogCard(running: Boolean) {
    val context = LocalContext.current
    var copied by remember { mutableStateOf(false) }
    LaunchedEffect(copied) {
        if (copied) {
            delay(1500)
            copied = false
        }
    }
    Column(
        Modifier.fillMaxWidth().palkaCard(selected = running).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            PalkaIconTile(Icons.Rounded.Terminal, size = 34.dp, iconSize = 16.dp, radius = 10.dp, tint = PalkaDesign.successText, background = Color.White.copy(alpha = 0.06f))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(stringResource(R.string.palka_runtime_logs), style = palkaText(15.sp, FontWeight.Bold))
                Text(
                    stringResource(if (running) R.string.palka_runtime_logs_live else R.string.palka_runtime_logs_saved),
                    style = palkaText(10.sp, FontWeight.Medium, PalkaDesign.textMuted)
                )
            }
            PalkaCircleButton(
                onClick = {
                    val text = Palka.runtimeLogs.joinToString("\n") {
                        "[${Palka.formatTime(it.timestamp)}] [${it.level.uppercase()}] ${it.message}"
                    }
                    (context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager)
                        .setPrimaryClip(ClipData.newPlainText("PalkaDPI", text))
                    copied = true
                },
                size = 40.dp,
                contentDescription = stringResource(R.string.palka_runtime_logs_copy)
            ) {
                Icon(
                    if (copied) Icons.Rounded.Check else Icons.Rounded.ContentCopy, null,
                    tint = if (copied) PalkaDesign.successText else PalkaDesign.textSecondary,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
        PalkaDivider()
        if (Palka.runtimeLogs.isEmpty()) {
            Text(stringResource(R.string.palka_runtime_logs_empty), style = palkaText(11.sp, color = PalkaDesign.textMuted, mono = true))
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(9.dp)) {
                Palka.runtimeLogs.takeLast(14).forEach { entry ->
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(Palka.formatTime(entry.timestamp), style = palkaText(10.sp, FontWeight.Medium, PalkaDesign.textDim, mono = true), modifier = Modifier.width(56.dp))
                        Box(
                            Modifier.padding(top = 5.dp).size(5.dp).background(
                                when (entry.level) {
                                    "success" -> PalkaDesign.success
                                    "error" -> PalkaDesign.errorText
                                    else -> PalkaDesign.textMuted
                                },
                                CircleShape
                            )
                        )
                        Text(
                            entry.message,
                            style = palkaText(10.sp, FontWeight.Medium, if (entry.level == "error") PalkaDesign.errorText else PalkaDesign.textSecondary, mono = true),
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }
        }
    }
}
