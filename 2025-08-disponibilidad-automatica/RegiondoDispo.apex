// La funcionalidad de esta clase consiste en Obtener la disponibilidad de los productos activos en Regiondo y cargarlos en un objeto en ejecuciones manuales a lo largo de el día por el operador. 
// En la versión V1 (Actual) se trabajará solo con 1 Regiondo. Al conseguir estabilidad, buscará la disponibilidad en todos de manera simultánea. 
// Breixo A. Herrera Rodríguez a 28/08/2025 (Comienzo del desarrollo V1)
// Breixo A. Herrera Rodríguez a 00-00-00 (Finalización del desarrollo V1)
//Lista de clases y sus funciones: 
//1- Config: Almacena las variables de configuración de llamada a Regiondo. 
//2- 
public with sharing class RegiondoDispo {

    // ===== Excepción específica =====
    public class RegiondoException extends Exception {}

    // ===== Config =====
    public class Config {
        public String baseUrl;
        public String publicKey;
        public String secretKey;
    }

    // Lee Custom Setting (o lanza error orientativo)
public static Config getConfigFromSettings() {
    Config c = new Config();
    c.baseUrl = 'https://api.regiondo.com/v1';

    try {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();

        // 1) PRIORIDAD: Custom Metadata Regiondo_Settings__mdt
        if (gd.containsKey('Regiondo_Settings__mdt')) {
            // Ajustar DeveloperName si se busca algo concreto (p.ej. 'Default')
            List<SObject> rows = Database.query(
                'SELECT BaseUrl__c, PublicKey__c, SecretKey__c FROM Regiondo_Settings__mdt LIMIT 1'
            );
            if (!rows.isEmpty()) {
                SObject cm = rows[0];
                String b  = (String)cm.get('BaseUrl__c');
                String pk = (String)cm.get('PublicKey__c');
                String sk = (String)cm.get('SecretKey__c');
                if (!String.isBlank(b))  c.baseUrl   = b.trim();
                if (!String.isBlank(pk)) c.publicKey = pk.trim();
                if (!String.isBlank(sk)) c.secretKey = sk.trim();
            }
        }
        // 2) Alternativa: Custom Setting Regiondo_Settings__c (si existiera)
        else if (gd.containsKey('Regiondo_Settings__c')) {
            List<SObject> rows = Database.query(
                'SELECT BaseUrl__c, PublicKey__c, SecretKey__c FROM Regiondo_Settings__c LIMIT 1'
            );
            if (!rows.isEmpty()) {
                SObject cs = rows[0];
                String b  = (String)cs.get('BaseUrl__c');
                String pk = (String)cs.get('PublicKey__c');
                String sk = (String)cs.get('SecretKey__c');
                if (!String.isBlank(b))  c.baseUrl   = b.trim();
                if (!String.isBlank(pk)) c.publicKey = pk.trim();
                if (!String.isBlank(sk)) c.secretKey = sk.trim();
            }
        }
    } catch (Exception e) {
        // dejamos que falle abajo con mensaje claro si faltan claves
    }

    if (String.isBlank(c.publicKey) || String.isBlank(c.secretKey)) {
        throw new CalloutException(
            'Regiondo: faltan claves en configuración. ' +
            'Asegúrate de tener Regiondo_Settings__mdt (o __c) con PublicKey__c y SecretKey__c.'
        );
    }
    return c;
}
    // ===== Helpers =====

    // Formatea Date a yyyy-MM-dd de forma segura (sin padLeft)
    private static String fmtDate(Date d) {
        if (d == null) return null;
        Datetime dt = Datetime.newInstanceGMT(d, Time.newInstance(0, 0, 0, 0));
        return dt.formatGmt('yyyy-MM-dd');
    }

    // Construye querystring con orden estable; ignora nulls
    private static String buildQueryString(Map<String, String> params) {
        if (params == null || params.isEmpty()) return '';
        List<String> keys = new List<String>(params.keySet());
        keys.sort();
        List<String> parts = new List<String>();
        for (String k : keys) {
            String v = params.get(k);
            if (v == null) continue;
            parts.add(EncodingUtil.urlEncode(k, 'UTF-8') + '=' + EncodingUtil.urlEncode(v, 'UTF-8'));
        }
        return String.join(parts, '&');
    }

    // Firma HMAC requerida por Regiondo
    private static void applyRegiondoHeaders(HttpRequest req, String publicKey, String secretKey, String queryString) {
        String ts = String.valueOf(Datetime.now().getTime()); // ms epoch
        String toSign = ts + (publicKey == null ? '' : publicKey) + (queryString == null ? '' : queryString);
        Blob mac = Crypto.generateMac('HmacSHA256', Blob.valueOf(toSign), Blob.valueOf(secretKey));
        String hashHex = EncodingUtil.convertToHex(mac).toLowerCase();

        req.setHeader('X-API-ID',   publicKey);
        req.setHeader('X-API-TIME', ts);
        req.setHeader('X-API-HASH', hashHex);
        req.setHeader('Accept',     'application/json');
        req.setHeader('User-Agent', 'ORG-RegiondoDispo/1.0 (Salesforce Apex)');

        System.debug(LoggingLevel.DEBUG, 'Regiondo HMAC toSign=' + toSign + ' hash=' + hashHex);
    }

    // Normaliza baseUrl/path evitando dobles o ausencias de '/'
    private static String joinUrl(String baseUrl, String path) {
        String b = baseUrl;
        if (String.isBlank(b)) b = 'https://api.regiondo.com/v1';
        if (b.endsWith('/')) b = b.substring(0, b.length() - 1);
        String p = String.isBlank(path) ? '' : path.trim();
        if (!String.isBlank(p) && !p.startsWith('/')) p = '/' + p;
        return b + p;
    }

    // ===== Envío GET: versión con settings =====
    private static HttpResponse sendGet(String path, Map<String, String> params) {
        Config cfg = getConfigFromSettings();
        return sendGetWithKeys(cfg.baseUrl, cfg.publicKey, cfg.secretKey, path, params);
    }

    // ===== Envío GET: versión con claves explícitas =====
    public static HttpResponse sendGetWithKeys(String baseUrl, String publicKey, String secretKey,
                                               String path, Map<String, String> params) {
        if (String.isBlank(publicKey) || String.isBlank(secretKey)) {
            throw new RegiondoException('Regiondo: publicKey/secretKey vacías en sendGetWithKeys.');
        }
        String qs  = buildQueryString(params);
        String url = joinUrl(baseUrl, path) + (String.isBlank(qs) ? '' : '?' + qs);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('GET');
        req.setTimeout(120000); // 120s
        applyRegiondoHeaders(req, publicKey, secretKey, qs);

        System.debug(LoggingLevel.INFO, 'Regiondo GET → ' + url);
        Http http = new Http();

        HttpResponse res;
        try {
            res = http.send(req);
        } catch (System.CalloutException e) {
            throw new RegiondoException('Regiondo: error de red/callout: ' + e.getMessage());
        }

        Integer code = res.getStatusCode();
        System.debug(LoggingLevel.INFO, 'Regiondo STATUS ' + res.getStatus() + ' | CODE ' + code);

        // Log de cuerpo truncado (evita PII en producción)
        String body = res.getBody();
        if (!String.isBlank(body)) {
            Integer max = 5000; // ajustable
            System.debug(LoggingLevel.DEBUG, 'Regiondo BODY ' + (body.length() > max ? body.substring(0, max) + '…[truncated]' : body));
        }

        if (code < 200 || code >= 300) {
            // Conserva parte del cuerpo para diagnósticos
            String snippet = String.isBlank(body) ? '' : (body.length() > 1000 ? body.substring(0, 1000) + '…' : body);
            throw new RegiondoException('Regiondo: HTTP ' + code + ' en ' + url + ' | Body=' + snippet);
        }
        return res;
    }

    // ===== WRAPPERS (con settings) =====

    public static HttpResponse getCategories() {
        return sendGet('/categories', null);
    }

    public static HttpResponse listProducts(Integer limitSize) {
        Map<String, String> p = new Map<String, String>();
        if (limitSize != null) p.put('limit', String.valueOf(limitSize));
        return sendGet('/products', p);
    }

    public static HttpResponse getProductById(String productId) {
        if (String.isBlank(productId)) throw new RegiondoException('productId requerido.');
        return sendGet('/products/' + EncodingUtil.urlEncode(productId, 'UTF-8'), null);
    }

    public static HttpResponse getAvailabilities(String variationId, Date dtFrom, Date dtTo) {
        if (String.isBlank(variationId)) throw new RegiondoException('variationId requerido.');
        if (dtFrom == null || dtTo == null) throw new RegiondoException('dt_from y dt_to requeridos.');
        if (dtFrom > dtTo) throw new RegiondoException('dt_from no puede ser posterior a dt_to.');

        Map<String, String> p = new Map<String, String>{
            'dt_from' => fmtDate(dtFrom),
            'dt_to'   => fmtDate(dtTo)
        };
        return sendGet('/products/availabilities/' + EncodingUtil.urlEncode(variationId, 'UTF-8'), p);
    }

    public static HttpResponse getAvailOptions(String variationId, Date theDate, String timeHHmm) {
        if (String.isBlank(variationId)) throw new RegiondoException('variationId requerido.');
        if (theDate == null || String.isBlank(timeHHmm)) throw new RegiondoException('date y time requeridos.');
        if (!Pattern.matches('^\\d{2}:\\d{2}$', timeHHmm)) throw new RegiondoException('time debe ser HH:mm');

        Map<String, String> p = new Map<String, String>{
            'date' => fmtDate(theDate),
            'time' => timeHHmm
        };
        return sendGet('/products/availoptions/' + EncodingUtil.urlEncode(variationId, 'UTF-8'), p);
    }

    // ===== Sobrecargas con claves =====

    public static HttpResponse getCategoriesWithKeys(String publicKey, String secretKey) {
        return sendGetWithKeys('https://api.regiondo.com/v1', publicKey, secretKey, '/categories', null);
    }

    public static HttpResponse listProductsWithKeys(String publicKey, String secretKey, Integer limitSize) {
        Map<String, String> p = new Map<String, String>();
        if (limitSize != null) p.put('limit', String.valueOf(limitSize));
        return sendGetWithKeys('https://api.regiondo.com/v1', publicKey, secretKey, '/products', p);
    }

    public static HttpResponse getProductByIdWithKeys(String publicKey, String secretKey, String productId) {
        if (String.isBlank(productId)) throw new RegiondoException('productId requerido.');
        return sendGetWithKeys('https://api.regiondo.com/v1', publicKey, secretKey,
                               '/products/' + EncodingUtil.urlEncode(productId, 'UTF-8'), null);
    }

    public static HttpResponse getAvailabilitiesWithKeys(String publicKey, String secretKey, String variationId, Date dtFrom, Date dtTo) {
        if (String.isBlank(variationId)) throw new RegiondoException('variationId requerido.');
        if (dtFrom == null || dtTo == null) throw new RegiondoException('dt_from y dt_to requeridos.');
        if (dtFrom > dtTo) throw new RegiondoException('dt_from no puede ser posterior a dt_to.');
        Map<String, String> p = new Map<String, String>{
            'dt_from' => fmtDate(dtFrom),
            'dt_to'   => fmtDate(dtTo)
        };
        return sendGetWithKeys('https://api.regiondo.com/v1', publicKey, secretKey,
                               '/products/availabilities/' + EncodingUtil.urlEncode(variationId, 'UTF-8'), p);
    }

    public static HttpResponse getAvailOptionsWithKeys(String publicKey, String secretKey, String variationId, Date theDate, String timeHHmm) {
        if (String.isBlank(variationId)) throw new RegiondoException('variationId requerido.');
        if (theDate == null || String.isBlank(timeHHmm)) throw new RegiondoException('date y time requeridos.');
        if (!Pattern.matches('^\\d{2}:\\d{2}$', timeHHmm)) throw new RegiondoException('time debe ser HH:mm');

        Map<String, String> p = new Map<String, String>{
            'date' => fmtDate(theDate),
            'time' => timeHHmm
        };
        return sendGetWithKeys('https://api.regiondo.com/v1', publicKey, secretKey,
                               '/products/availoptions/' + EncodingUtil.urlEncode(variationId, 'UTF-8'), p);
    }
}