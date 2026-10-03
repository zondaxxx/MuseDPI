package io.github.romanvht.byedpi.palka.ui

import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Error
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay

/** Shared visual language, a 1:1 port of PalkaDesign.swift. */
object PalkaDesign {
    val background = Color(0xFF06131C)
    val surface = Color(0xFF122430)
    val elevatedSurface = Color(0xFF1A3340)

    val textPrimary = Color.White.copy(alpha = 0.96f)
    val textSecondary = Color.White.copy(alpha = 0.68f)
    val textMuted = Color.White.copy(alpha = 0.62f)
    val textDim = Color.White.copy(alpha = 0.22f)

    val border = Color.White.copy(alpha = 0.10f)
    val borderStrong = Color.White.copy(alpha = 0.15f)
    val success = Color(0xFF4DC4C2)
    val successText = Color(0xFFA8E8E0)
    val errorText = Color(0xFFF78282)
    val warning = Color(0xFFFF9F0A)
    val onPrimary = Color(0xFF07070E)

    val screenPadding = 20.dp
    val sectionSpacing = 28.dp
    val cardRadius = 24.dp

    /** iOS "timingCurve(0.32, 0.72, 0, 1)" used for every press and entrance. */
    val easing = CubicBezierEasing(0.32f, 0.72f, 0f, 1f)
}

fun palkaText(
    size: TextUnit,
    weight: FontWeight = FontWeight.Normal,
    color: Color = PalkaDesign.textPrimary,
    tracking: TextUnit = TextUnit.Unspecified,
    mono: Boolean = false,
    lineHeight: TextUnit = TextUnit.Unspecified
) = TextStyle(
    fontSize = size,
    fontWeight = weight,
    color = color,
    letterSpacing = tracking,
    fontFamily = if (mono) FontFamily.Monospace else FontFamily.Default,
    lineHeight = lineHeight
)

/** Near-black canvas with a faint 44 dp grid, radial vignette and a bottom fade. */
@Composable
fun PalkaBackground(modifier: Modifier = Modifier) {
    val step = with(LocalDensity.current) { 44.dp.toPx() }
    val line = with(LocalDensity.current) { 0.5.dp.toPx() }
    val fade = with(LocalDensity.current) { 220.dp.toPx() }
    Canvas(modifier.fillMaxSize()) {
        drawRect(PalkaDesign.background)
        val gridColor = PalkaDesign.success.copy(alpha = 0.08f)
        var y = size.height * 0.65f
        while (y <= size.height) {
            val wave = androidx.compose.ui.graphics.Path().apply {
                moveTo(0f, y)
                cubicTo(size.width * 0.35f, y - 30f, size.width * 0.65f, y + 30f, size.width, y)
            }
            drawPath(wave, gridColor, style = androidx.compose.ui.graphics.drawscope.Stroke(line))
            y += step
        }
        drawRect(
            Brush.radialGradient(
                colors = listOf(Color.Transparent, PalkaDesign.background.copy(alpha = 0.32f)),
                center = center,
                radius = maxOf(size.width, size.height) * 0.72f
            )
        )
        drawRect(
            Brush.verticalGradient(
                colors = listOf(PalkaDesign.background.copy(alpha = 0f), PalkaDesign.background),
                startY = size.height - fade,
                endY = size.height
            ),
            topLeft = Offset(0f, size.height - fade)
        )
    }
}

/** `.palkaCard(radius:selected:)` */
fun Modifier.palkaCard(radius: Dp = PalkaDesign.cardRadius, selected: Boolean = false): Modifier {
    val shape = RoundedCornerShape(radius)
    val fill = if (selected) Brush.linearGradient(
        listOf(Color.White.copy(alpha = 0.10f), Color.White.copy(alpha = 0.05f))
    ) else Brush.linearGradient(listOf(PalkaDesign.surface, PalkaDesign.surface))
    return this
        .clip(shape)
        .background(fill, shape)
        .border(1.dp, if (selected) PalkaDesign.borderStrong else PalkaDesign.border, shape)
}

/**
 * Visible focus for D-pad, keyboard and TV (the app keeps the leanback launcher):
 * the custom controls draw no ripple, so focus gets its own white outline.
 */
@Composable
fun Modifier.palkaFocusRing(interaction: MutableInteractionSource, shape: Shape): Modifier {
    val focused by interaction.collectIsFocusedAsState()
    return if (focused) this.border(2.dp, Color.White.copy(alpha = 0.75f), shape) else this
}

/** PalkaPressButtonStyle: scale 0.975 and dim while pressed. */
@Composable
fun Modifier.palkaPressable(
    enabled: Boolean = true,
    pressedScale: Float = 0.975f,
    shape: Shape = RoundedCornerShape(PalkaDesign.cardRadius),
    onClick: () -> Unit
): Modifier {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(
        if (pressed && enabled) pressedScale else 1f, tween(150, easing = PalkaDesign.easing), label = "press"
    )
    val alpha by animateFloatAsState(if (pressed && enabled) 0.82f else 1f, tween(150), label = "pressAlpha")
    return this
        .graphicsLayer { scaleX = scale; scaleY = scale; this.alpha = alpha }
        .palkaFocusRing(interaction, shape)
        .clickable(interaction, indication = null, enabled = enabled, role = Role.Button, onClick = onClick)
}

private val whiteFill = Brush.linearGradient(listOf(Color.White, Color(0xFFE8EDF7)))

@Composable
fun PalkaPrimaryButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    content: @Composable RowScope.() -> Unit
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed && enabled) 0.98f else 1f, tween(150, easing = PalkaDesign.easing), label = "primary")
    val shape = RoundedCornerShape(14.dp)
    Row(
        modifier
            .fillMaxWidth()
            .heightIn(min = 56.dp)
            .graphicsLayer { scaleX = scale; scaleY = scale; alpha = if (enabled) 1f else 0.70f }
            .shadow(if (pressed) 14.dp else 10.dp, shape, ambientColor = Color.White, spotColor = Color.White.copy(alpha = 0.35f))
            .clip(shape)
            .background(whiteFill)
            .border(0.5.dp, Color.White.copy(alpha = 0.9f), shape)
            .then(if (interaction.collectIsFocusedAsState().value) Modifier.border(3.dp, PalkaDesign.success, shape) else Modifier)
            .clickable(interaction, null, enabled = enabled, role = Role.Button, onClick = onClick)
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically
    ) {
        ProvideStyle(palkaText(16.sp, FontWeight.Bold, PalkaDesign.onPrimary), PalkaDesign.onPrimary) { content() }
    }
}

@Composable
fun PalkaSecondaryButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    content: @Composable RowScope.() -> Unit
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed && enabled) 0.97f else 1f, tween(150, easing = PalkaDesign.easing), label = "secondary")
    val shape = RoundedCornerShape(14.dp)
    Row(
        modifier
            .fillMaxWidth()
            .heightIn(min = 52.dp)
            .graphicsLayer { scaleX = scale; scaleY = scale; alpha = if (enabled) 1f else 0.55f }
            .clip(shape)
            .background(Color.White.copy(alpha = if (pressed) 0.11f else 0.07f))
            .border(1.dp, PalkaDesign.border, shape)
            .palkaFocusRing(interaction, shape)
            .clickable(interaction, null, enabled = enabled, role = Role.Button, onClick = onClick)
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically
    ) {
        ProvideStyle(palkaText(15.sp, FontWeight.SemiBold, PalkaDesign.textSecondary), PalkaDesign.textSecondary) { content() }
    }
}

@Composable
fun PalkaCompactPrimaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed && enabled) 0.97f else 1f, tween(150, easing = PalkaDesign.easing), label = "compact")
    Box(
        modifier
            .widthIn(min = 88.dp)
            .heightIn(min = 44.dp)
            .graphicsLayer { scaleX = scale; scaleY = scale; alpha = if (enabled) 1f else 0.55f }
            .clip(CircleShape)
            .background(whiteFill)
            .border(0.5.dp, Color.White.copy(alpha = 0.9f), CircleShape)
            .then(if (interaction.collectIsFocusedAsState().value) Modifier.border(3.dp, PalkaDesign.success, CircleShape) else Modifier)
            .clickable(interaction, null, enabled = enabled, role = Role.Button, onClick = onClick)
            .padding(horizontal = 16.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(text, style = palkaText(13.sp, FontWeight.Bold, PalkaDesign.onPrimary), maxLines = 1)
    }
}

@Composable
private fun ProvideStyle(style: TextStyle, tint: Color, content: @Composable () -> Unit) {
    androidx.compose.runtime.CompositionLocalProvider(
        androidx.compose.material3.LocalTextStyle provides style,
        androidx.compose.material3.LocalContentColor provides tint,
        content = content
    )
}

/** Pulsing green dot when active, dim when idle. */
@Composable
fun PalkaStatusDot(isActive: Boolean) {
    val pulse = rememberInfiniteTransition(label = "dot")
    val alpha by pulse.animateFloat(
        1f, 0.42f, infiniteRepeatable(tween(1200, easing = LinearEasing), RepeatMode.Reverse), label = "dotAlpha"
    )
    Box(
        Modifier
            .size(8.dp)
            .then(if (isActive) Modifier.shadow(6.dp, CircleShape, spotColor = PalkaDesign.success, ambientColor = PalkaDesign.success) else Modifier)
            .alpha(if (isActive) alpha else 1f)
            .background(if (isActive) PalkaDesign.success else PalkaDesign.textDim, CircleShape)
    )
}

@Composable
fun PalkaIconTile(
    icon: ImageVector,
    size: Dp = 44.dp,
    iconSize: Dp = 19.dp,
    radius: Dp = 13.dp,
    tint: Color = PalkaDesign.textPrimary,
    background: Color = Color.White.copy(alpha = 0.07f)
) {
    Box(
        Modifier.size(size).clip(RoundedCornerShape(radius)).background(background),
        contentAlignment = Alignment.Center
    ) {
        Icon(icon, null, tint = tint, modifier = Modifier.size(iconSize))
    }
}

@Composable
fun PalkaCircleButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    size: Dp = 44.dp,
    enabled: Boolean = true,
    contentDescription: String? = null,
    content: @Composable BoxScope.() -> Unit
) {
    Box(
        modifier
            .size(size)
            .palkaPressable(enabled = enabled, shape = CircleShape, onClick = onClick)
            .clip(CircleShape)
            .background(Color.White.copy(alpha = 0.055f))
            .border(1.dp, Color.White.copy(alpha = 0.07f), CircleShape)
            .then(if (contentDescription != null) Modifier.semantics { this.contentDescription = contentDescription } else Modifier),
        contentAlignment = Alignment.Center,
        content = content
    )
}

@Composable
fun PalkaSpinner(color: Color = PalkaDesign.textPrimary, size: Dp = 18.dp) {
    CircularProgressIndicator(modifier = Modifier.size(size), color = color, strokeWidth = 2.dp)
}

/** Uppercase caption + stacked content with 10 dp gaps (PalkaSettingsSection). */
@Composable
fun PalkaSection(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(
            title.uppercase(),
            style = palkaText(11.sp, FontWeight.SemiBold, PalkaDesign.textMuted, tracking = 0.7.sp),
            modifier = Modifier.padding(start = 4.dp)
        )
        Column(verticalArrangement = Arrangement.spacedBy(10.dp), content = content)
    }
}

enum class PalkaFeedbackKind { Success, Error }

@Composable
fun PalkaFeedbackBanner(text: String, kind: PalkaFeedbackKind) {
    val color = if (kind == PalkaFeedbackKind.Success) PalkaDesign.successText else PalkaDesign.errorText
    val shape = RoundedCornerShape(9.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 38.dp)
            .clip(shape)
            .background(color.copy(alpha = 0.08f))
            .border(1.dp, color.copy(alpha = 0.18f), shape)
            .padding(horizontal = 12.dp, vertical = 9.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            if (kind == PalkaFeedbackKind.Success) Icons.Rounded.CheckCircle else Icons.Rounded.Error,
            null, tint = color, modifier = Modifier.size(16.dp)
        )
        Text(text, style = palkaText(12.sp, FontWeight.Medium, color), modifier = Modifier.weight(1f))
    }
}

/** Icon badge + uppercase caption + monospaced value + chevron: SettingsStaticInfoView on iOS. */
@Composable
fun PalkaNavRow(
    title: String,
    text: String?,
    icon: ImageVector,
    showsDisclosure: Boolean = true,
    enabled: Boolean = true,
    onClick: (() -> Unit)? = null
) {
    val shape = RoundedCornerShape(16.dp)
    val content: @Composable () -> Unit = {
        Row(
            Modifier.fillMaxWidth().palkaCard(16.dp).padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            PalkaIconBadge(icon)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(title.uppercase(), style = palkaText(11.sp, FontWeight.SemiBold, PalkaDesign.textMuted, tracking = 0.4.sp))
                if (!text.isNullOrBlank()) {
                    Text(text, style = palkaText(14.sp, color = PalkaDesign.textPrimary, mono = true, lineHeight = 20.sp))
                }
            }
            if (showsDisclosure) {
                Icon(Icons.Rounded.ChevronRight, null, tint = PalkaDesign.textDim, modifier = Modifier.size(18.dp))
            }
        }
    }
    if (onClick != null) Box(Modifier.alpha(if (enabled) 1f else 0.55f).palkaPressable(enabled = enabled, shape = shape, onClick = onClick)) { content() }
    else content()
}

/** PalkaIconBadge: 40 dp tile, 19 dp glyph, faint border. */
@Composable
fun PalkaIconBadge(icon: ImageVector) {
    val shape = RoundedCornerShape(12.dp)
    Box(
        Modifier
            .size(40.dp)
            .clip(shape)
            .background(Color.White.copy(alpha = 0.06f))
            .border(1.dp, Color.White.copy(alpha = 0.07f), shape),
        contentAlignment = Alignment.Center
    ) {
        Icon(icon, null, tint = PalkaDesign.textPrimary, modifier = Modifier.size(19.dp))
    }
}

@Composable
fun PalkaToggleRow(title: String, text: String, checked: Boolean, enabled: Boolean = true, onChange: (Boolean) -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .palkaCard()
            .clickable(enabled = enabled, role = Role.Switch) { onChange(!checked) }
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, style = palkaText(14.sp, FontWeight.SemiBold))
            Text(text, style = palkaText(11.sp, color = PalkaDesign.textMuted, lineHeight = 15.sp))
        }
        Switch(
            checked = checked,
            onCheckedChange = onChange,
            enabled = enabled,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = PalkaDesign.success,
                checkedBorderColor = Color.Transparent,
                uncheckedThumbColor = Color.White.copy(alpha = 0.9f),
                uncheckedTrackColor = Color.White.copy(alpha = 0.12f),
                uncheckedBorderColor = Color.Transparent
            )
        )
    }
}

/** Uppercase pill used for catalog tags and the ON/OFF badge. */
@Composable
fun PalkaTag(text: String, mono: Boolean = false, height: Dp = 28.dp) {
    val shape = RoundedCornerShape(14.dp)
    Box(
        Modifier
            .heightIn(min = height)
            .clip(shape)
            .background(Color.White.copy(alpha = 0.055f))
            .border(1.dp, Color.White.copy(alpha = 0.07f), shape)
            .padding(horizontal = 9.dp, vertical = 6.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text.uppercase(),
            style = palkaText(if (mono) 11.sp else 10.sp, FontWeight.SemiBold, if (mono) PalkaDesign.textMuted else PalkaDesign.textSecondary, tracking = if (mono) TextUnit.Unspecified else 0.45.sp, mono = mono, lineHeight = 13.sp),
            maxLines = 2,
            overflow = TextOverflow.Ellipsis
        )
    }
}

/** Fade + 16 dp rise on first appearance, staggered by `delay` (palkaEntrance). */
@Composable
fun Modifier.palkaEntrance(delayMs: Int = 0): Modifier {
    var visible by rememberSaveable { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        if (!visible) {
            delay(delayMs.toLong())
            visible = true
        }
    }
    val progress by animateFloatAsState(if (visible) 1f else 0f, tween(380, easing = PalkaDesign.easing), label = "entrance")
    val rise = with(LocalDensity.current) { 16.dp.toPx() }
    return graphicsLayer { alpha = progress; translationY = (1f - progress) * rise }
}

@Composable
fun PalkaDivider(modifier: Modifier = Modifier) {
    Box(modifier.fillMaxWidth().height(1.dp).background(Color.White.copy(alpha = 0.07f)))
}

@Composable
fun PalkaProgressBar(progress: Float) {
    val animated by animateFloatAsState(progress.coerceIn(0f, 1f), tween(300), label = "progress")
    Box(
        Modifier.fillMaxWidth().height(4.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.10f))
    ) {
        Box(Modifier.fillMaxWidth(animated).height(4.dp).clip(CircleShape).background(PalkaDesign.textPrimary))
    }
}

@Composable
fun PalkaHeaderText(title: String, text: String, titleSize: TextUnit = 28.sp) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(title, style = palkaText(titleSize, FontWeight.Black, tracking = (-0.85).sp))
        Text(text, style = palkaText(14.sp, color = PalkaDesign.textSecondary, lineHeight = 20.sp))
    }
}

/** featureHeader: 48 dp icon tile + 24 sp heavy title + description. */
@Composable
fun PalkaFeatureHeader(title: String, text: String, icon: ImageVector) {
    Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        PalkaIconTile(icon, size = 48.dp, iconSize = 22.dp, radius = 14.dp, background = Color.White.copy(alpha = 0.06f))
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(title, style = palkaText(24.sp, FontWeight.Black, tracking = (-0.65).sp))
            Text(text, style = palkaText(13.sp, color = PalkaDesign.textSecondary, lineHeight = 18.sp))
        }
    }
}
