@isTest
private class ConteoRegiondoTest {

    // Mock para simular respuestas de API Regiondo
    class MockRegiondoCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            // Respuesta simulada con referencias order_id
            //String body = '{"order_id":"123"},{"order_id":"456"}';
            res.setBody('[{"order_number":"123", "event_date_time":"2025-05-22 12:00:00"}, {"order_number":"456", "event_date_time":"2025-05-22 13:00:00"}]');



            return res;
        }
    }

    @isTest
    static void testCompareRegiondoWithSalesforce() {
        // Registrar mock HTTP
        Test.setMock(HttpCalloutMock.class, new MockRegiondoCallout());
        
         ConteoRegiondo.originKeys.put(
        ConteoRegiondo.Origin.SITE_I,
        new ConteoRegiondo.RegiondoAuth('dummyKey', 'dummySecret')
    );
        
        Contact ctc = new Contact();
        ctc.LastName = 'test';
        insert ctc;
        

        insert new Booking__c(
            PlatformReferencev2__c = '123',
            IntegrationPlatform__c = 'Regiondo',
            PrimaryContact__c = ctc.Id
        );


        Test.startTest();
        ConteoRegiondo.ComparisonResult result = ConteoRegiondo.compareRegiondoWithSalesforce();
        Test.stopTest();


        System.assertEquals(2, result.regiondoCount, 'Debe haber 2 referencias de Regiondo');
    }

    @isTest
    static void testGetOnlyInRegiondoByOrigin() {

        ConteoRegiondo.regiondoReferencesByOrigin.clear();
        ConteoRegiondo.regiondoReferencesByOrigin.put(
            ConteoRegiondo.Origin.SITE_I,
            new List<String>{'789', '456'}
        );

        Set<String> onlyList = new Set<String>{'456'};
        Test.startTest();
        Map<ConteoRegiondo.Origin, List<String>> result =
            ConteoRegiondo.getOnlyInRegiondoByOrigin(onlyList);
        Test.stopTest();
        
        System.assert(result.containsKey(ConteoRegiondo.Origin.SITE_I), 'Debe contener SITE_I');
        System.assertEquals(1, result.get(ConteoRegiondo.Origin.SITE_I).size());
        System.assertEquals('456', result.get(ConteoRegiondo.Origin.SITE_I)[0]);
    }

    @isTest
    static void testDebugCompareRegiondoWithSalesforce() {
        Test.setMock(HttpCalloutMock.class, new MockRegiondoCallout());

        Contact ctc = new Contact();
        ctc.LastName = 'test';
        insert ctc;
        
        insert new Booking__c(
            PlatformReferencev2__c = '123',
            IntegrationPlatform__c = 'Regiondo',
            PrimaryContact__c = ctc.Id
        );

        Test.startTest();
        ConteoRegiondo.debugCompareRegiondoWithSalesforce();
        Test.stopTest();
    }
}