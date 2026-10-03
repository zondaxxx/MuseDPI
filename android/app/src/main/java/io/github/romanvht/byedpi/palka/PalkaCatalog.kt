package io.github.romanvht.byedpi.palka

import android.util.Base64
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.google.gson.Gson
import com.google.gson.JsonParser
import com.google.gson.annotations.SerializedName
import com.google.gson.reflect.TypeToken
import io.github.romanvht.byedpi.BuildConfig
import io.github.romanvht.byedpi.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import net.i2p.crypto.eddsa.EdDSAEngine
import net.i2p.crypto.eddsa.EdDSAPublicKey
import net.i2p.crypto.eddsa.spec.EdDSANamedCurveTable
import net.i2p.crypto.eddsa.spec.EdDSAPublicKeySpec
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.Locale

data class OnlineStrategy(
    val id: String,
    val name: String,
    val nameRu: String?,
    val summary: String,
    val summaryRu: String?,
    val services: List<String>?,
    val stability: String?,
    val stabilityRu: String?,
    val sourceName: String?,
    val sourceURL: String?,
    val commandArgs: List<String>,
    val minimumAppVersion: String?,
    val minimumEngineVersion: String?,
    val deprecated: Boolean?
) {
    private val russian: Boolean
        get() = Locale.getDefault().language.lowercase(Locale.ROOT).startsWith("ru")

    val displayName: String get() = if (russian) (nameRu ?: name) else name
    val displaySummary: String get() = if (russian) (summaryRu ?: summary) else summary
    val displayStability: String get() = if (russian) (stabilityRu ?: stability ?: "") else (stability ?: "")

    val searchableText: String
        get() = (listOf(name, nameRu, summary, summaryRu, stability, stabilityRu, sourceName) + services.orEmpty())
            .filterNotNull().joinToString(" ").lowercase()

    val sourceLink: String? get() = sourceURL?.takeIf { it.startsWith("https://") }
}

data class OnlineStrategyCatalog(
    val schemaVersion: Int,
    val generation: Int,
    val updatedAt: String,
    val minimumAppVersion: String?,
    val minimumEngineVersion: String?,
    @SerializedName("revokedStrategyIDs") val revokedStrategyIDs: List<String>?,
    val strategies: List<OnlineStrategy>
)

private data class CatalogCacheEntry(val data: String, val signature: String, val savedAt: Long)

/**
 * Signed PalkaDPI strategy catalog: the same Ed25519-signed JSON the iOS app
 * uses, fetched from GitHub and verified with the embedded public key before
 * anything from it is turned into a ByeDPI command line. Keeps the last three
 * verified versions so a bad catalog can be rolled back from the UI.
 */
object PalkaCatalog {
    private const val TAG = "PalkaCatalog"
    const val CATALOG_URL = "https://raw.githubusercontent.com/zondaxxx/PalkaDPI/main/strategy-catalog.json"
    const val SIGNATURE_URL = "https://raw.githubusercontent.com/zondaxxx/PalkaDPI/main/strategy-catalog.json.sig"
    private const val PUBLIC_KEY_BASE64 = "18bFOLUFcXXG6/56v8NnWS/SO6SxTxFIhdD5Vmz43jg="
    private const val MAX_BYTES = 512 * 1024
    private const val CACHE_FILE = "palka_catalog_cache.json"
    /** byedpi version vendored in android/app/src/main/cpp/byedpi. */
    const val ENGINE_VERSION = "0.17.3"

    private val gson = Gson()
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var cache: List<CatalogCacheEntry> = emptyList()
    private var loadedCache = false

    var strategies by mutableStateOf(emptyList<OnlineStrategy>()); private set
    var updatedAt by mutableStateOf(""); private set
    var generation by mutableStateOf(0); private set
    var isLoading by mutableStateOf(false); private set
    var isUsingCache by mutableStateOf(false); private set
    var errorText by mutableStateOf<String?>(null); private set

    val canUsePreviousVersion: Boolean get() = cache.size > 1

    class CatalogException(message: String) : Exception(message)

    private val cacheFile get() = File(Palka.context.filesDir, CACHE_FILE)

    fun loadCache() {
        if (loadedCache) return
        loadedCache = true
        cache = runCatching {
            gson.fromJson<List<CatalogCacheEntry>>(
                cacheFile.readText(), object : TypeToken<List<CatalogCacheEntry>>() {}.type
            )
        }.getOrNull().orEmpty()
        cache.firstOrNull()?.let { apply(it.data.toByteArray(), it.signature, isCache = true) }
    }

    fun load() {
        loadCache()
        if (isLoading) return
        isLoading = true
        errorText = null
        scope.launch {
            val result = withContext(Dispatchers.IO) {
                runCatching {
                    val sig = String(download(SIGNATURE_URL, 4096)).trim()
                    val data = download(CATALOG_URL, MAX_BYTES)
                    sig to data
                }
            }
            isLoading = false
            result.onSuccess { (sig, data) ->
                if (apply(data, sig, isCache = false)) saveVerified(String(data), sig)
                else if (errorText == null) errorText = Palka.str(R.string.palka_catalog_invalid_signature)
            }.onFailure {
                errorText = it.message ?: Palka.str(R.string.palka_catalog_invalid_response)
            }
        }
    }

    fun usePreviousVersion() {
        if (cache.size < 2) return
        val previous = cache[1]
        if (apply(previous.data.toByteArray(), previous.signature, isCache = true)) {
            cache = listOf(previous) + cache.filterIndexed { i, _ -> i != 1 }
            persist()
        }
    }

    private fun saveVerified(data: String, sig: String) {
        cache = (listOf(CatalogCacheEntry(data, sig, System.currentTimeMillis())) + cache.filter { it.data != data }).take(3)
        persist()
    }

    private fun persist() = runCatching { cacheFile.writeText(gson.toJson(cache)) }

    private fun download(url: String, limit: Int): ByteArray {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = 10_000
        connection.readTimeout = 10_000
        connection.useCaches = false
        connection.setRequestProperty("Cache-Control", "no-cache")
        try {
            if (connection.responseCode != 200) throw CatalogException("HTTP ${connection.responseCode}")
            val bytes = connection.inputStream.use { input ->
                val output = java.io.ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                while (true) {
                    val count = input.read(buffer)
                    if (count == -1) break
                    if (count > limit - output.size()) throw CatalogException("response too large")
                    output.write(buffer, 0, count)
                }
                output.toByteArray()
            }
            if (bytes.size > limit) throw CatalogException("response too large: ${bytes.size}")
            return bytes
        } finally {
            connection.disconnect()
        }
    }

    private fun apply(data: ByteArray, signatureBase64: String, isCache: Boolean): Boolean {
        val catalog = runCatching { verifyAndParse(data, signatureBase64) }
            .onFailure { Log.w(TAG, "catalog rejected: ${it.message}") }
            .getOrNull() ?: return false
        if (!isCache) {
            val highest = cache.mapNotNull {
                runCatching { gson.fromJson(it.data, OnlineStrategyCatalog::class.java).generation }.getOrNull()
            }.maxOrNull() ?: 0
            if (catalog.generation < highest) return false
        }
        val usable = usable(catalog)
        if (usable.isEmpty()) return false
        strategies = usable
        updatedAt = catalog.updatedAt
        generation = catalog.generation
        isUsingCache = isCache
        errorText = null
        return true
    }

    @Throws(CatalogException::class)
    fun verifyAndParse(data: ByteArray, signatureBase64: String): OnlineStrategyCatalog {
        val signature = runCatching { Base64.decode(signatureBase64, Base64.DEFAULT) }
            .getOrElse { throw CatalogException("signature is not base64") }
        if (!verify(data, signature)) throw CatalogException("catalog signature is invalid")

        // Gson ignores Kotlin nullability, so required fields are checked on the raw
        // JSON first; a signed but malformed catalog is rejected, never half-loaded.
        val root = runCatching { JsonParser.parseString(String(data)).asJsonObject }
            .getOrElse { throw CatalogException("catalog JSON is invalid") }
        if (!root.has("updatedAt") || !root.get("updatedAt").isJsonPrimitive) throw CatalogException("catalog has no updatedAt")
        val rawStrategies = root.get("strategies")?.takeIf { it.isJsonArray }?.asJsonArray
            ?: throw CatalogException("catalog has no strategies")
        rawStrategies.forEach { element ->
            val o = element.takeIf { it.isJsonObject }?.asJsonObject ?: throw CatalogException("strategy is not an object")
            for (field in listOf("id", "name", "summary")) {
                if (o.get(field)?.takeIf { it.isJsonPrimitive && it.asJsonPrimitive.isString } == null) {
                    throw CatalogException("strategy without $field")
                }
            }
            val args = o.get("commandArgs")?.takeIf { it.isJsonArray }?.asJsonArray
                ?: throw CatalogException("strategy without commandArgs")
            if (args.any { !it.isJsonPrimitive || !it.asJsonPrimitive.isString }) throw CatalogException("non-string argument")
        }
        val catalog = runCatching { gson.fromJson(root, OnlineStrategyCatalog::class.java) }
            .getOrElse { throw CatalogException("catalog JSON is invalid") }
            ?: throw CatalogException("catalog JSON is empty")
        if (catalog.schemaVersion != 2) throw CatalogException("unsupported schema ${catalog.schemaVersion}")
        if (catalog.generation <= 0 || catalog.strategies.isEmpty() || catalog.strategies.size > 100) {
            throw CatalogException("catalog has an invalid strategy list")
        }
        if (!versionAtLeast(appVersion(), catalog.minimumAppVersion) ||
            !versionAtLeast(ENGINE_VERSION, catalog.minimumEngineVersion)
        ) throw CatalogException("catalog needs a newer app")
        val ids = catalog.strategies.map { it.id }
        if (ids.toSet().size != ids.size) throw CatalogException("duplicate strategy ids")
        return catalog
    }

    private fun verify(data: ByteArray, signature: ByteArray): Boolean = try {
        val spec = EdDSANamedCurveTable.getByName(EdDSANamedCurveTable.ED_25519)
        val keyBytes = Base64.decode(PUBLIC_KEY_BASE64, Base64.DEFAULT)
        val publicKey = EdDSAPublicKey(EdDSAPublicKeySpec(keyBytes, spec))
        val engine = EdDSAEngine(MessageDigest.getInstance(spec.hashAlgorithm))
        engine.initVerify(publicKey)
        engine.update(data)
        engine.verify(signature)
    } catch (e: Exception) {
        Log.w(TAG, "verify failed", e)
        false
    }

    private fun appVersion() = BuildConfig.VERSION_NAME.substringBefore('-')

    private fun versionAtLeast(current: String, required: String?): Boolean {
        if (required.isNullOrBlank()) return true
        val l = current.split('.').map { it.toIntOrNull() ?: 0 }
        val r = required.split('.').map { it.toIntOrNull() ?: 0 }
        for (i in 0 until maxOf(l.size, r.size)) {
            val a = l.getOrElse(i) { 0 }
            val b = r.getOrElse(i) { 0 }
            if (a != b) return a > b
        }
        return true
    }

    /** Strategies that are not revoked, deprecated or too new, catalog order preserved. */
    fun usable(catalog: OnlineStrategyCatalog): List<OnlineStrategy> {
        val revoked = catalog.revokedStrategyIDs?.toSet() ?: emptySet()
        return catalog.strategies.filter {
            it.id !in revoked && it.deprecated != true && it.id.isNotEmpty() &&
                it.commandArgs.isNotEmpty() && it.commandArgs.size <= 160 &&
                it.commandArgs.none { a -> a.length > 4096 || a.contains('\n') || a.contains('\u0000') } &&
                versionAtLeast(appVersion(), it.minimumAppVersion) &&
                versionAtLeast(ENGINE_VERSION, it.minimumEngineVersion)
        }
    }
}
