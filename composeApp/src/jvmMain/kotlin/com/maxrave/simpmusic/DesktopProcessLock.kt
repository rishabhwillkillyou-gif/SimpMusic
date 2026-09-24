package com.maxrave.simpmusic

import java.io.File
import java.io.RandomAccessFile
import java.nio.channels.FileChannel
import java.nio.channels.FileLock
import java.nio.channels.OverlappingFileLockException

/**
 * OS-level guard for the desktop app.
 *
 * ComposeTray's single-instance helper is kept for its normal restore signalling, but a real
 * file lock closes the startup race where two Windows processes can both reach DataStore before
 * the helper has finished registering the first instance.
 */
object DesktopProcessLock {
    private var channel: FileChannel? = null
    private var lock: FileLock? = null

    private val lockFile: File by lazy {
        File(System.getProperty("user.home"), ".rishify/rishify.instance.lock")
    }

    private val restoreRequestFile: File by lazy {
        File(System.getProperty("java.io.tmpdir"), "rishify_restore.request")
    }

    @Synchronized
    fun tryAcquire(): Boolean {
        if (lock?.isValid == true) return true

        return try {
            lockFile.parentFile?.mkdirs()
            val raf = RandomAccessFile(lockFile, "rw")
            val openedChannel = raf.channel
            val acquired = openedChannel.tryLock()

            if (acquired == null) {
                openedChannel.close()
                raf.close()
                false
            } else {
                channel = openedChannel
                lock = acquired
                true
            }
        } catch (_: OverlappingFileLockException) {
            false
        } catch (_: Exception) {
            false
        }
    }

    fun requestRestore() {
        runCatching {
            restoreRequestFile.writeText(System.currentTimeMillis().toString())
        }
    }

    fun consumeRestoreRequest(): Boolean =
        runCatching {
            if (!restoreRequestFile.exists()) {
                false
            } else {
                restoreRequestFile.delete()
                true
            }
        }.getOrDefault(false)
}
