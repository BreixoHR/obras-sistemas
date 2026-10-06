/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 01-14-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
public with sharing class BookingFilesController {
    @AuraEnabled(cacheable=true)
    public static List<ContentDocumentLink> getFilesForBooking(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException('Record ID is required.');
        }
        List<Id> ticketsIds = getIds([SELECT Id FROM Ticket__c WHERE Booking__c = :recordId]);
        if(ticketsIds.isEmpty() || ticketsIds.size() == 0) {
            return new List<ContentDocumentLink>();
        }
        return [
            SELECT Id,
                   ContentDocumentId,
                   ContentDocument.Title,
                   ContentDocument.CreatedDate,
                   ContentDocument.FileType
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :ticketsIds
            ORDER BY ContentDocument.CreatedDate DESC
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static Boolean isBookingtoFiles(Id recordId) {
        List<Booking__c> bookingList = [SELECT Id, ProductInfo__c FROM Booking__c WHERE Id=:recordId ];
        List<BookingsToFiles__mdt> metadataList = [SELECT Id FROM BookingsToFiles__mdt WHERE ProductName__c =:bookingList[0].ProductInfo__c];

        return metadataList.size() > 0;
    }

    @AuraEnabled(cacheable=true)
    public static List<ContentDocumentLink> getFilesFromFilesForBooking(Id recordId) {
        return [
            SELECT Id,
                   ContentDocumentId,
                   ContentDocument.Title,
                   ContentDocument.CreatedDate,
                   ContentDocument.FileType
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
            ORDER BY ContentDocument.CreatedDate DESC
        ];
    }

    private static List<Id> getIds(List<Ticket__c> tickets){
        List<Id> recordIds = new List<Id>();
        for(sObject record : tickets) {
            recordIds.add(record.Id);
        }
        return recordIds;
    }
}