@isTest
private class ConteoRegiondoControllerTest {

    class MockRegiondoCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('[{"order_number":"123", "event_date_time":"2025-05-22 12:00:00"}, {"order_number":"456", "event_date_time":"2025-05-22 13:00:00"}]');
            return res;
        }
    }

    @isTest
    static void testControllerLogic() {
        Contact ctc = new Contact();
        ctc.LastName = 'test';
        insert ctc;
        

        insert new Booking__c(
            PlatformReferencev2__c = '123',
            IntegrationPlatform__c = 'Regiondo',
            PrimaryContact__c = ctc.Id
        );


        Test.setMock(HttpCalloutMock.class, new MockRegiondoCallout());

        Test.startTest();
        ConteoRegiondoController controller = new ConteoRegiondoController();
        Test.stopTest();


        System.assertEquals(2, controller.regiondoCount, 'Regiondo count esperado');
        //System.assertEquals('001', controller.onlyInRegiondo[0]);
        System.assert(controller.onlyInRegiondo.containsKey('123'), 'Debe contener la referencia 123');

        System.assertNotEquals(null, controller.regiondoByOrigin);
        System.assert(controller.regiondoByOrigin.size() > 0, 'Debe haber datos distribuidos por origen');


        List<ConteoRegiondoController.OriginWrapper> wrappers = controller.getWrapperList();
        System.assert(wrappers.size() > 0, 'wrapperList debe contener al menos un origen');
        System.assertNotEquals(null, wrappers[0].origin);
        System.assertNotEquals(null, wrappers[0].refs);
    }
}