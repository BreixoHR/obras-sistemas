public with sharing class ConteoRegiondo {

    //********************************************************************************//
    //********************************************************************************//
    //********************************************************************************//
    //***********************        ZONA REGIONDO         ***************************//
    //********************************************************************************//
    //********************************************************************************//
    //********************************************************************************//
    public static Map<Origin, List<String>> regiondoReferencesByOrigin = new Map<Origin, List<String>>();
    public static Map<Origin, Map<String, DateTime>> regiondoReferenceDatesByOrigin = new Map<Origin, Map<String, DateTime>>();

    public enum Origin {
        SITE_I, SITE_J, SITE_K, SITE_D, SITE_H, SITE_L,
        MUSEO, SITE_P, SITE_C, SITE_G, SITE_M, SITE_N,
        SITE_B, SITE_F
    }

    public class RegiondoAuth {
        public String publicKey, secretKey;
        public RegiondoAuth(String pub, String sec) {
            publicKey = pub; secretKey = sec;
        }
    }

    // Cambiado: now ComparisonResult almacena Map<String, DateTime> para onlyInRegiondo
    public class ComparisonResult {
        public Integer regiondoCount, salesforceCount;
        public Map<String, DateTime> onlyInRegiondo;
        public ComparisonResult(Integer r, Integer s, Map<String, DateTime> onlyMap) {
            regiondoCount = r;
            salesforceCount = s;
            onlyInRegiondo = onlyMap;
        }
    }

    public static Map<Origin, RegiondoAuth> originKeys = new Map<Origin, RegiondoAuth>{
        Origin.SITE_I => new RegiondoAuth('REGIONDO_PUBLIC_KEY', 'REGIONDO_SECRET_KEY'),
        Origin.SITE_J => new RegiondoAuth('REGIONDO_PUBLIC_KEY', 'REGIONDO_SECRET_KEY'),
        Origin.SITE_K => new RegiondoAuth('REGIONDO_PUBLIC_KEY', 'REGIONDO_SECRET_KEY'),
        Origin.SITE_D => new RegiondoAuth('REGIONDO_PUBLIC_KEY', 'REGIONDO_SECRET_KEY'),
        Origin.SITE_H => new RegiondoAuth('REGIONDO_PUBLIC_KEY', 'REGIONDO_SECRET_KEY'),
        Origin.SITE_L => new RegiondoAuth('REGIONDO_PUBLIC_KEY', 'REGIONDO_SECRET_KEY'),
        Origin.MUSEO => new RegiondoAuth('REGIONDO_PUBLIC_KEY', 'REGIONDO_SECRET_KEY'),
        Origin.SITE_P => new RegiondoAuth('REGIONDO_PUBLIC_KEY', 'REGIONDO_SECRET_KEY'),
        Origin.SITE_C => new RegiondoAuth('REGIONDO_PUBLIC_KEY', 'REGIONDO_SECRET_KEY'),
        Origin.SITE_G => new RegiondoAuth('REGIONDO_PUBLIC_KEY', 'REGIONDO_SECRET_KEY'),
        Origin.SITE_M => new RegiondoAuth('REGIONDO_PUBLIC_KEY', 'REGIONDO_SECRET_KEY'),
        Origin.SITE_N => new RegiondoAuth('REGIONDO_PUBLIC_KEY', 'REGIONDO_SECRET_KEY'),
        Origin.SITE_B => new RegiondoAuth('REGIONDO_PUBLIC_KEY', 'REGIONDO_SECRET_KEY'),
        Origin.SITE_F => new RegiondoAuth('REGIONDO_PUBLIC_KEY', 'REGIONDO_SECRET_KEY')
    };

    public static Map<String, DateTime> getAllRegiondoReferences() {
        Map<String, DateTime> totalRefs = new Map<String, DateTime>();
        regiondoReferencesByOrigin.clear();
        regiondoReferenceDatesByOrigin.clear();

        for (Origin o : Origin.values()) {
            try {
                Map<String, DateTime> originRefs = getReferencesFromOrigin(o);
                totalRefs.putAll(originRefs);
                regiondoReferencesByOrigin.put(o, new List<String>(originRefs.keySet()));
                regiondoReferenceDatesByOrigin.put(o, originRefs);
            } catch (Exception e) {
                System.debug('Error origen ' + o + ': ' + e.getMessage());
            }
        }

        return totalRefs;
    }

    private static Map<String, DateTime> getReferencesFromOrigin(Origin origin) {
    Map<String, DateTime> references = new Map<String, DateTime>();
    RegiondoAuth creds = originKeys.get(origin);
    if (creds == null) return references;

    Date yesterday = Date.today().addDays(-1);
    String formattedDate = DateTime.newInstance(yesterday, Time.newInstance(0,0,0,0))
                              .format('yyyy-MM-dd');
    String range = EncodingUtil.urlEncode(formattedDate + ',' + formattedDate, 'UTF-8');

    System.debug('Fechas: ' + formattedDate);

    Integer page = 1, perPage = 250, maxPages = 30;
    Boolean hasMore = true;
    Pattern p = Pattern.compile('"order_number"\\s*:\\s*"([^"]+)"');
    Pattern datePattern = Pattern.compile('"event_date_time"\\s*:\\s*"([^"]+)"');

    while (hasMore && page <= maxPages) {
        String ts = String.valueOf(DateTime.now().getTime() / 1000);
        String params =
                      'suppress_response_code=false'
                      + '&debug=false'
                      + '&sandboxauth=false'
                      + '&date_range_by=date_bought'
                      + '&date_range=' + range
                      + '&page=' + page
                      + '&limit=' + perPage;

        String fullUrl = 'https://api.regiondo.com/v1/supplier/bookings?' + params;

        Blob hash = Crypto.generateMac(
            'HmacSHA256',
            Blob.valueOf(ts + creds.publicKey + params),
            Blob.valueOf(creds.secretKey)
        );
        String signature = EncodingUtil.convertToHex(hash);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(fullUrl);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept-Language', 'en-US');
        req.setHeader('api_key', signature);
        req.setHeader('X-API-HASH', signature);
        req.setHeader('X-API-TIME', ts);
        req.setHeader('X-API-ID', creds.publicKey);

        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (Exception ex) {
            System.debug('Excepción HTTP ' + origin + ': ' + ex.getMessage());
            break;
        }

        if (res.getStatusCode() == 200) {
            String body = res.getBody().unescapeHtml4().unescapeUnicode();
            System.debug(' BODY BODY en ' + origin + ', página ' + page + ': ' + body);

            Matcher m = p.matcher(body);
            Matcher dm = datePattern.matcher(body);
            Integer countThisPage = 0;
            while (m.find() && dm.find()) {
                String ref = m.group(1);
                String dateStr = dm.group(1);
                if (String.isNotBlank(ref) && String.isNotBlank(dateStr)) {
                    try {
                        // Comprobar si dateStr tiene hora (espacio entre fecha y hora)
                        DateTime dt;
                        if (dateStr.contains(' ')) {
                            // Ejemplo: "2025-05-23 10:00:00"
                            dt = DateTime.valueOf(dateStr);
                        } else {
                            // Solo fecha, añadir hora 00:00:00
                            dt = DateTime.valueOf(dateStr + ' 00:00:00');
                        }
                        references.put(ref, dt);
                    } catch (Exception e) {
                        System.debug('Fecha no válida para ' + ref + ': ' + dateStr);
                    }
                }
                countThisPage++;
            }
            if (countThisPage < perPage) {
                hasMore = false;
            } else {
                page++;
                System.debug('Referencias encontradas en ' + origin + ': ' + references.size());
            }
        } else {
            System.debug('HTTP ' + res.getStatusCode() + ' origen ' + origin);
            break;
        }
    }
    return references;
}

    public static Set<String> getAllSalesforceReferences() {
        //Por favor las fechas que no se toquen :) si no el programa no funciona, es espectacular
        DateTime start= DateTime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0)).addDays(-1);
        DateTime fin   = DateTime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0)).addSeconds(-1);
        Set<String> refs = new Set<String>();
        for (Booking__c b : [
            SELECT PlatformReferencev2__c
              FROM Booking__c
             WHERE SaleDateTime__c >=: start
               AND SaleDateTime__c <=: fin
               AND PlatformReferencev2__c != NULL
               AND IntegrationPlatform__c = 'Regiondo'
        ]) {
            try {
                refs.add(b.PlatformReferencev2__c);
            } catch (Exception e) {
                System.debug('ID no válido en Salesforce: ' + b.PlatformReferencev2__c);
            }
        }
        return refs;
    }

    public static ComparisonResult compareRegiondoWithSalesforce() {
        // Obtenemos todos los refs con fechas de Regiondo
        Map<String, DateTime> allRegiondoRefs = getAllRegiondoReferences();
        Set<String> allRegiondoRefKeys = allRegiondoRefs.keySet();
        Set<String> salesforceRefs = getAllSalesforceReferences();

        // Convertir a Long para comparación numérica segura
        Set<Long> rrSet = new Set<Long>();
        for (String i : allRegiondoRefKeys) {
            try {
                rrSet.add(Long.valueOf(i));
            } catch (Exception ex) {
                System.debug('ID Regiondo no convertible a Long: ' + i);
            }
        }
        Set<Long> sfSet = new Set<Long>();
        for (String i : salesforceRefs) {
            try {
                sfSet.add(Long.valueOf(i));
            } catch (Exception ex) {
                System.debug('ID Salesforce no convertible a Long: ' + i);
            }
        }

        // Obtener los IDs que están solo en Regiondo (con tipo Long)
        Set<Long> onlyInteger = new Set<Long>(rrSet);
        onlyInteger.removeAll(sfSet);

        // Map para los únicos con sus fechas
        Map<String, DateTime> onlyMap = new Map<String, DateTime>();

        // Revertimos a String para que coincida el Map original, y ponemos fecha
        for (Long idLong : onlyInteger) {
            String idStr = String.valueOf(idLong);
            if (allRegiondoRefs.containsKey(idStr)) {
                onlyMap.put(idStr, allRegiondoRefs.get(idStr));
            }
        }

        return new ComparisonResult(rrSet.size(), sfSet.size(), onlyMap);
    }

    public static Map<Origin, List<String>> getOnlyInRegiondoByOrigin(Set<String> onlyRegiondoIds) {
        Map<Origin, List<String>> mapByOrigin = new Map<Origin, List<String>>();
        for (Origin o : Origin.values()) {
            mapByOrigin.put(o, new List<String>());
        }
        // Recorrer las referencias únicas y asignarlas a su origen
        for (String id : onlyRegiondoIds) {
            for (Origin o : Origin.values()) {
                if (regiondoReferencesByOrigin.containsKey(o)) {
                    List<String> refs = regiondoReferencesByOrigin.get(o);
                    if (refs != null && refs.contains(id)) {
                        mapByOrigin.get(o).add(id);
                        break; // ya asignado, salir del bucle
                    }
                }
            }
        }
        return mapByOrigin;
    }

    public static void debugCompareRegiondoWithSalesforce() {
        ComparisonResult res = compareRegiondoWithSalesforce();
        System.debug('Total Regiondo: ' + res.regiondoCount
                  + ', Total SF: ' + res.salesforceCount
                  + ', Solo en Regiondo: ' + res.onlyInRegiondo);
        Map<Origin, List<String>> byOrg = getOnlyInRegiondoByOrigin(res.onlyInRegiondo.keySet());
        for (Origin o : byOrg.keySet()) {
            System.debug('Únicos en ' + o + ': ' + byOrg.get(o));
        }
    }



    //********************************************************************************//
    //********************************************************************************//
    //********************************************************************************//
    //***********************         ZONA TURITOP         ***************************//
    //********************************************************************************//
    //********************************************************************************//
    //********************************************************************************//

    public static Map<String, Map<String, DateTime>> turitopReferenceDatesByCode = new Map<String, Map<String, DateTime>>();


    // Cambiado: now ComparisonResult almacena Map<String, DateTime> para onlyInTuritop
    public class ComparisonResultTuritop {
        public Integer turitopCount, salesforceCount;
        public Map<String, Map<String, DateTime>> onlyInTuritop;
        public ComparisonResultTuritop(Integer r, Integer s, Map<String, Map<String, DateTime>> onlyMap) {
            turitopCount = r;
            salesforceCount = s;
            onlyInTuritop = onlyMap;
        }
    }
    
    //Función para obtener el token de acceso de Turitop
    private static String getOAuthToken(String SHORT_ID, String SECRET_KEY) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://app.turitop.com/v1/authorization/grant');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');

        String body = JSON.serialize(new Map<String, String>{
            'short_id' => SHORT_ID,
            'secret_key' => SECRET_KEY
        });
        req.setBody(body);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            Map<String, Object> data = (Map<String, Object>) responseMap.get('data');
            return (String) data.get('access_token');
        } else {
            throw new CalloutException('Error al obtener token: '***' - ' + res.getBody());
        }
    }


    private static Map<String, Map<String, DateTime>> getTuritopBookings() {
    Map<String, Map<String, DateTime>> bookingsTuritop = new Map<String, Map<String, DateTime>>();
    String TURI_SHORT_ID = 'TURITOP_SHORT_ID';
    String TURI_SECRET  = '***';

    Date yesterday = Date.today().addDays(-1);
    DateTime inicio = DateTime.newInstance(yesterday, Time.newInstance(0,0,0,0));
    DateTime fin = DateTime.newInstance(yesterday, Time.newInstance(23,59,59,999));
    
    String inicioEpoch = String.valueOf(inicio.getTime() / 1000);
    String finEpoch    = String.valueOf(fin.getTime() / 1000);

    System.debug('Fechas: ' + inicioEpoch + ' - ' + finEpoch);

    //Intentamos crear el access token
    try {
            String token = getOAuthToken(TURI_SHORT_ID, TURI_SECRET);
            if (String.isNotBlank(token)) {
                bookingsTuritop = getBookings(token, inicioEpoch , finEpoch);
            }
        } catch (Exception e) {
            System.debug('Error al obtener reservas desde Turitop: ' + e.getMessage());
        }
    return bookingsTuritop;
    }

    //Función para obtener los datos de Turitop
    private static Map<String, Map<String, DateTime>> getBookings(String token, String fromD, String toD) {
    
        Map<String, Map<String, DateTime>> bookingsTuritop = new Map<String, Map<String, DateTime>>();

        
        //Patterns para buscar sobre el booking
        Integer page = 1, perPage = 250, maxPages = 30;
        Boolean hasMore = true;
        Pattern p = Pattern.compile('"product_name"\\s*:\\s*"([^"]+)"');
        Pattern oNumber = Pattern.compile('"short_id"\\s*:\\s*"([^"]+)"');
        Pattern datePattern = Pattern.compile('"date_booking"\\s*:\\s*"([^"]+)"');


        while (hasMore && page <= maxPages) {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://app.turitop.com/v1/booking/getbookings');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Accept', 'application/json');

            Map<String, Object> payload = new Map<String, Object>{
                'access_token' => token,
                'data' => new Map<String, Object>{
                    'filter' => new Map<String, Object>{
                        'bookings_date_from' => fromD,
                        'bookings_date_to' => toD,
                        'booking_page' => page,
                        'booking_limit' => perPage,
                        'show_prebookings' => true,
                        'show_deleted' => true
                    }
                }
            };
            req.setBody(JSON.serialize(payload));

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                Map<String, Object> data = (Map<String, Object>) result.get('data');
                List<Object> bookings = (List<Object>) data.get('bookings');
                System.debug('Respuesta: ' + data);
                System.debug('bookings: ' + bookings);

                Integer countThisPage = 0;

                for (Object b : bookings) {
                    Map<String, Object> booking = (Map<String, Object>) b;
                    String name = (String) booking.get('product_name');
                    String bookingID = (String) booking.get('short_id');
                    String dateStr = String.valueOf(booking.get('date_event'));

                    if (String.isNotBlank(name) && String.isNotBlank(bookingID) && String.isNotBlank(dateStr)) {
                        try {
                            DateTime dt;
                            Long seconds = Long.valueOf(dateStr);
                            dt = DateTime.newInstance(1970, 1, 1, 0, 0, 0).addSeconds(seconds.intValue());
                            bookingsTuritop.put(bookingID, new Map<String, DateTime>{name => dt});
                        } catch (Exception ex) {
                            System.debug('Error al convertir fecha para ' + bookingID + ': ' + ex.getMessage());
                        }
                    }

                    countThisPage++;
                }

                if (countThisPage < perPage) {
                    hasMore = false;
                } else {
                    page++;
                }

            } else {
                System.debug('Error en la página ' + page + ': ' + res.getStatusCode() + ' - ' + res.getBody());
                hasMore = false; // detener bucle en caso de error
            }
        }
        return bookingsTuritop;
    }

    public static Set<String> getAllSalesforceReferencesTuritop() {
        //Por favor las fechas que no se toquen :) si no el programa no funciona, es espectacular
        DateTime start= DateTime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0)).addDays(-1);
        DateTime fin   = DateTime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0)).addSeconds(-1);
        Set<String> refs = new Set<String>();
        for (Booking__c b : [
            SELECT PlatformReferencev2__c
              FROM Booking__c
             WHERE SaleDateTime__c >=: start
               AND SaleDateTime__c <=: fin
               AND PlatformReferencev2__c != NULL
               AND IntegrationPlatform__c = 'Turitop'
        ]) {
            try {
                refs.add(b.PlatformReferencev2__c);
            } catch (Exception e) {
                System.debug('ID no válido en Salesforce: ' + b.PlatformReferencev2__c);
            }
        }
        return refs;
    }

    public static ComparisonResultTuritop compareTuritopWithSalesforce() {
        Map<String, Map<String, DateTime>> allTuritopRefs = getTuritopBookings();
        // allTuritopRefs es Map<String, Map<String, DateTime>>
        Set<String> allTuritopRefKeys = new Set<String>(allTuritopRefs.keySet());
        Set<String> salesforceRefs = getAllSalesforceReferencesTuritop();

        Map<String, Map<String, DateTime>> onlyMap = new Map<String, Map<String, DateTime>>(allTuritopRefs);

        //Convertir a hexadecimal para comparación numérica segura
        Long TuriHex;
        Long SFHex;
        for (String actual : allTuritopRefKeys) {
            try {
                TuriHex = stringToBinaryAsLong(actual);
            } catch (Exception ex) {
                System.debug('ID Turitop no convertible a hexadecimal: ' + actual);
            }
            for (String actualSF : salesforceRefs) {
                try {
                    SFHex = stringToBinaryAsLong(actualSF);
                } catch (Exception ex) {
                    System.debug('ID Salesforce no convertible a hexadecimal: ' + actualSF);
                }
                if (TuriHex == SFHex) {
                    onlyMap.remove(actual);
                    break; // salir del bucle interno
                }
            }
        }
        
        return new ComparisonResultTuritop(allTuritopRefKeys.size(), salesforceRefs.size(), onlyMap);
    }
    
   public static Long stringToBinaryAsLong(String input) {
    String binaryStr = '';
    for (Integer i = 0; i < input.length(); i++) {
        Integer ascii = (Integer)input.charAt(i);
        String bin = '';
        Integer value = ascii;

        // Convertimos el valor ASCII a binario (8 bits)
        while (value > 0) {
            Integer remainder = Math.mod(value, 2);
            bin = String.valueOf(remainder) + bin;
            value = value / 2;
        }

        while (bin.length() < 8) {
            bin = '0' + bin;
        }

        binaryStr += bin;
    }

    Long result = 0;
    Integer len = binaryStr.length();
    for (Integer i = 0; i < len; i++) {
        if (binaryStr.substring(i, i + 1).equals('1')) {
            result += (Long)Math.pow(2, len - 1 - i);
        }
    }

    return result;
}


    public static void debugCompareTuritopWithSalesforce() {
        ComparisonResultTuritop res = compareTuritopWithSalesforce();
        System.debug('Total RegionTuritop: ' + res.turitopCount
                  + ', Total SF: ' + res.salesforceCount
                  + ', Solo en Turitop: ' + res.onlyInTuritop);
    }


}