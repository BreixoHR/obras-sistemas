public with sharing class PdfFilesUpdater {

    @AuraEnabled(cacheable=true)
    public static String getPdfBase64(String bookingId) {
        String linkedEntityId = getBookingOrTicketPDF(bookingId);
            
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, ContentDocument.CreatedDate 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :linkedEntityId
            ORDER BY ContentDocument.CreatedDate DESC 
            LIMIT 1
        ];
                
        if (links.isEmpty()) {
            return null; 
        }
            
        ContentDocumentLink latestLink = links[0];
            
        ContentVersion latestVersion = [
            SELECT VersionData 
            FROM ContentVersion 
            WHERE ContentDocumentId = :latestLink.ContentDocumentId 
            AND FileExtension = 'pdf'
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];

        return EncodingUtil.base64Encode(latestVersion.VersionData);
        

    }

    private static String getBookingOrTicketPDF(String bookingId) {
        Boolean isInCustomMetadata = BookingFilesController.isBookingtoFiles(bookingId);
        if(isInCustomMetadata){
            return bookingId;
        }else{
            List<Ticket__c> tickets = [
                SELECT Id, Name, CreatedDate
                FROM Ticket__c
                WHERE Booking__c = :bookingId 
                AND Name LIKE '%Entrada'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (tickets.isEmpty()) {
                return null;
            }
            return  tickets[0].Id;
        }
    }
    
    
    @AuraEnabled(cacheable=true)
    public static Boolean isPdfFieldEmpty(String bookingId) {
        Booking__c booking = [SELECT PDF__c FROM Booking__c WHERE Id = :bookingId LIMIT 1];
        return String.isBlank(booking.PDF__c);
    }
    
    @AuraEnabled
    public static Boolean saveBookingDate(String bookingId, String fechaVisita) {
        try {
            Booking__c booking = [SELECT Id, StartDateTimeOnlyDate__c, PDF__c FROM Booking__c WHERE Id = :bookingId LIMIT 1];
            
            Date fechaVisitaDate;
            
            if (booking.StartDateTimeOnlyDate__c != null && fechaVisita != null) {
                Date startDate = getDateFromString(booking.StartDateTimeOnlyDate__c.format());
                fechaVisitaDate = getDateFromString(fechaVisita);
                
                if (startDate != null && fechaVisitaDate != null) {
                    if (startDate.equals(fechaVisitaDate)) {
                        booking.StartDateMatch__c = true;
                    } else {
                        booking.StartDateMatch__c = false;
                    }
                }
            }
            if(booking.PDF__c != fechaVisitaDate.format()){
                booking.PDF__c = fechaVisitaDate.format();
                update booking;
                return true;
            }else{
                return false;
            }
        } catch (Exception e) {
            System.debug('Error saving fechaVisita and StartDateMatch__c: ' + e.getMessage());
            return false;
        }
    }

    @AuraEnabled
    public static Boolean saveLocalizador(String localizador, String bookingId) {
        try {
            if(checkLocalInBooking(bookingId, new List<String> {localizador})){
                return true;
            }

            List<Localizador_Reserva__c> localizadorExistente = [
                SELECT Id, Codigo_localizador__c 
                FROM Localizador_Reserva__c 
                WHERE Reserva__c != :bookingId AND  Codigo_localizador__c = :localizador
                LIMIT 1
            ];
            Booking__c bookingToUpdate = [SELECT Id, LocalizadorPDF__c FROM Booking__c WHERE Id = :bookingId LIMIT 1];
             
            if (localizadorExistente.isEmpty()) {
                bookingToUpdate.LocalizadorPDF__c = localizador;

                Localizador_Reserva__c localizadorReserva = new Localizador_Reserva__c();
                localizadorReserva.Codigo_localizador__c = localizador;
                localizadorReserva.Reserva__c = bookingId;

                insert localizadorReserva;

                update bookingToUpdate;

                return true;
            }else{
                deleteContentdocument(bookingId);
                bookingToUpdate.LocDuplicatedPDF__c = true;
                bookingToUpdate.LocalizadorPDFError__c = localizador; 
                update bookingToUpdate;
                return false;
            }
        } catch (Exception e) {
            System.debug('Error saving localizador: ' + e.getMessage());
        }
        return false;
    }

    @AuraEnabled
    public static Boolean saveMultipleLocalizadores(List<String> localizadores, String bookingId) {
        try {
            if(checkLocalInBooking(bookingId, localizadores)){
                return true;
            }
            List<Localizador_Reserva__c> localizadorList = new List<Localizador_Reserva__c>();
            List<Localizador_Reserva__c> existingLocalizadores = [
                SELECT Id, Codigo_localizador__c 
                FROM Localizador_Reserva__c 
                WHERE Reserva__c != :bookingId AND  Codigo_localizador__c IN :localizadores
                LIMIT 1
            ];
            Booking__c bookingToUpdate = [SELECT Id, LocalizadorPDF__c FROM Booking__c WHERE Id = :bookingId LIMIT 1];

            if (!existingLocalizadores.isEmpty()) {
                deleteContentdocument(bookingId);
                bookingToUpdate.LocDuplicatedPDF__c = true;
                update bookingToUpdate;
                return false;
            }

            for (String localizador : localizadores) {
                Localizador_Reserva__c localizadorReserva = new Localizador_Reserva__c();
                localizadorReserva.Codigo_localizador__c = localizador;
                localizadorReserva.Reserva__c = bookingId;
                localizadorList.add(localizadorReserva);
            }

            insert localizadorList;
            return true;
        } catch (Exception e) {
            System.debug('Error saving multiple localizadores: ' + e.getMessage());
        }
        return false;
    }

    public static Boolean checkLocalInBooking(String bookingId, List<String>  localizador){
        List<Localizador_Reserva__c> localizadorExistente = [
            SELECT Id, Codigo_localizador__c 
            FROM Localizador_Reserva__c 
            WHERE Reserva__c = :bookingId AND  Codigo_localizador__c IN :localizador
            LIMIT 1
        ];

        return !localizadorExistente.isEmpty();
    }

    private static void deleteContentdocument(String bookingId){
        String ticketIdOrBooking = getBookingOrTicketPDF(bookingId);
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, ContentDocument.CreatedDate 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :ticketIdOrBooking
            ORDER BY ContentDocument.CreatedDate DESC 
            LIMIT 1
        ];

        List<Ticket__c> tickets =[SELECT Id, TicketUploaded__c, Public_url__c FROM Ticket__c WHERE Id =:ticketIdOrBooking  LIMIT 1];
       
        if(!tickets.isEmpty()){
            Ticket__c ticket = tickets[0];
            if(ticket.TicketUploaded__c == true){
                ticket.TicketUploaded__c = false;
                ticket.Public_url__c = null;
                update ticket;
            }
        }

        if (!links.isEmpty()) {
            String docId = links[0].ContentDocumentId;
            delete [SELECT Id FROM ContentDocument WHERE Id = :docId];
        }

    }


    private static Date getDateFromString(String dateString) {
        try {
            System.debug('Date String: ' + dateString);
            if (dateString != null) {
                dateString = dateString.replace('-', '/');
                if (dateString.contains('T')) {
                dateString = dateString.split('T')[0];
                    String[] dateParts = dateString.split('/');
            if (dateParts.size() == 3) {
                String day = dateParts[2];
                String month = dateParts[1];
                String year = dateParts[0];
                dateString = day + '/' + month + '/' + year;
            }
                }
                return Date.parse(dateString);
            }
        } catch (Exception e) {
            System.debug('Error parsing date: ' + e.getMessage());
        }
        return null;
    }

    @AuraEnabled(cacheable=true)
    public static List<RegexRule> getRegexRules() {
        List<Pdf_Reader__mdt> rules = [
            SELECT Page_Condition__c, RegExp__c, Target_Field__c
            FROM Pdf_Reader__mdt 
        ];

        List<RegexRule> result = new List<RegexRule>();
        for (Pdf_Reader__mdt rule : rules) {
            RegexRule r = new RegexRule();
            r.regex = rule.RegExp__c;
            r.target = rule.Target_Field__c;
            r.condition = rule.Page_Condition__c;
            result.add(r);
        }

        return result;
    }

    public class RegexRule {
        @AuraEnabled public String regex;
        @AuraEnabled public String target;
        @AuraEnabled public String condition;
    }
}