package com.maxrave.simpmusic.ui.component

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.weight
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.maxrave.domain.manager.DataStoreManager
import com.maxrave.simpmusic.ui.screen.home.EqualizerSection
import com.maxrave.simpmusic.ui.theme.typo
import com.maxrave.simpmusic.viewModel.SettingsViewModel
import org.koin.compose.viewmodel.koinViewModel

/**
 * Player-side access to RishiFy's built-in 10-band equalizer.
 *
 * This deliberately reuses [EqualizerSection] instead of maintaining a second set of presets or
 * DSP controls. Changes are live while the song keeps playing.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EqualizerQuickBottomSheet(
    onDismiss: () -> Unit,
    viewModel: SettingsViewModel = koinViewModel(),
) {
    val enabled by viewModel.equalizerEnabled.collectAsStateWithLifecycle()
    val type by viewModel.equalizerType.collectAsStateWithLifecycle()
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    LaunchedEffect(Unit) {
        viewModel.getEqualizer()
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = MaterialTheme.colorScheme.surface,
    ) {
        Column(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .padding(bottom = 24.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = "RishiFy Equalizer",
                        style = typo().titleMedium,
                    )
                    Text(
                        text = "Presets and manual 10-band tuning apply live without changing stream quality.",
                        style = typo().bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Switch(
                    checked = enabled && type == DataStoreManager.EQUALIZER_TYPE_BUILT_IN,
                    onCheckedChange = { checked ->
                        if (checked && type != DataStoreManager.EQUALIZER_TYPE_BUILT_IN) {
                            viewModel.setEqualizerType(DataStoreManager.EQUALIZER_TYPE_BUILT_IN)
                        }
                        viewModel.setEqualizerEnabled(checked)
                    },
                )
            }

            Spacer(modifier = Modifier.height(4.dp))

            if (enabled && type == DataStoreManager.EQUALIZER_TYPE_BUILT_IN) {
                EqualizerSection(viewModel = viewModel)
            } else {
                Text(
                    text = "Turn on the RishiFy equalizer to choose a preset or draw your own curve.",
                    style = typo().bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(vertical = 20.dp),
                )
            }
        }
    }
}
