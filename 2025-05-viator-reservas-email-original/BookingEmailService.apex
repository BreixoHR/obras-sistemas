global class BookingEmailService implements Messaging.InboundEmailHandler {
    global Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
        
        try {
            String emailBody;
            emailBody = email.htmlbody.stripHtmlTags();
            String emailSubject = email.subject;
            String recipientEmail = email.toAddresses.isEmpty() ? null : email.toAddresses[0];
            String productName = '';
            //Get contact info and create contact
            Contact relatedContact = null;
            relatedContact = new Contact();
            relatedContact.LastName = extractDetail(emailBody, '(?:Lead Traveler Name:|Nombre del viajero principal:)\\s*(.*?)(?=Traveler Names:|Nombres de los viajeros:)');
            
            if (String.isNotBlank(extractDetail(emailBody, 'Date of Birth:\\s*((\\d{2}/\\d{2}/\\d{4})|(\\d{4}-\\d{2}-\\d{2})|([A-Z]{3} \\d{1,2} \\d{4}))'))) {
                relatedContact.Birthdate = Date.valueOf(convertDateFormat(extractDetail(emailBody, 'Date of Birth:\\s*((\\d{2}/\\d{2}/\\d{4})|(\\d{4}-\\d{2}-\\d{2})|([A-Z]{3} \\d{1,2} \\d{4}))')));
            }
            if (String.isNotBlank(extractDetail(emailBody, '(?:Phone:|Teléfono:)\\s*(.+?)\\s*(?=Send the customer|Envíe un mensaje al cliente)'))) {
                relatedContact.Phone = extractDetail(emailBody, '(?:Phone:|Teléfono:)\\s*(.+?)\\s*(?=Send the customer|Envíe un mensaje al cliente)');
            }

            List<Contact> existingContacts = [SELECT Id FROM Contact WHERE LastName = :relatedContact.LastName AND Phone = :relatedContact.Phone AND Birthdate =: relatedContact.Birthdate LIMIT 1];

            if (!existingContacts.isEmpty()) {
                relatedContact.Id = existingContacts[0].Id;
            }else{
                insert relatedContact;
            }
            

            //Get product info and relate
            Product2 relatedProduct = null;
            String product = extractDetail(emailBody, '(?:Product Code:|Código del producto:)\\s*(\\S+)');
            String productAux1 = product+',%';
            String productAux2 = '%,'+product;
            String productAux3 = '%,'+product+',%';

            if (String.isNotBlank(product)) {
                List<Product2> products = [SELECT Id FROM Product2 WHERE ViatorCode__c = :product
                OR ViatorCode__c LIKE :productAux1 
                OR ViatorCode__c LIKE :productAux2 
                OR ViatorCode__c LIKE :productAux3 LIMIT 1];
                if (!products.isEmpty()) {
                    relatedProduct = products[0];
                }
            }

            if(String.isNotBlank(extractDetail(emailBody, '(?:Tour Name:|Nombre del Tour:)\\s*(.+?)\\s*(?=Travel Date:|Fecha del viaje:)'))){
                productName = extractDetail(emailBody, '(?:Tour Name:|Nombre del Tour:)\\s*(.+?)\\s*(?=Travel Date:|Fecha del viaje:)');
            }
            
            //Get booking info and create
            Group bookingQueueGranada = [SELECT Id FROM Group WHERE DeveloperName = 'Cola_Reservas_Sede'];
             String travelersText = extractDetail(emailBody, '(?:Travelers:|Viajeros:)\\s*(.*?)(?=Product Code:)');            
            Integer adultsCount = 0;
            Integer childrenCount = 0;
            Integer infantCount = 0;
            
            if (String.isNotBlank(travelersText)) {
                List<String> travelerCategories = travelersText.split(',');
                for (String category : travelerCategories) {
                    String cleanedCategory = category.trim();
                    Pattern categoryPattern = Pattern.compile('(\\d+)\\s*(Adult|Adults|Child|Children|Infant|Infants)s*,?');
                    Matcher matcher = categoryPattern.matcher(cleanedCategory);
                    if (matcher.find()) {
                        Integer count = Integer.valueOf(matcher.group(1));
                        String type = matcher.group(2);
                        System.debug('matcher' + type);
                        if (type == 'Adult' || type == 'Adults') {
                            adultsCount += count;
                        } else if (type == 'Child' || type == 'Children') {
                            childrenCount += count;
                        } else if (type == 'Infant' || type == 'Infants') {
                            infantCount += count;
                        }
                    } else {
                        System.debug('Skipping invalid traveler category: ' + cleanedCategory);
                    }
                }
            }
            String status;
            if (emailSubject != null && (emailSubject.containsIgnoreCase('responda') || emailSubject.containsIgnoreCase('solicitud'))) {
                status = 'En espera de confirmación';
            } else {
                status = 'Confirmada';
            }
            
            Booking__c booking = new Booking__c();
            booking.OwnerId = bookingQueueGranada.Id;
            booking.Status__c = status;
            booking.AdultsNumber__c = adultsCount;
            booking.ChildrenNumber__c = childrenCount;
            booking.BabyNumber__c = infantCount;
            booking.PlatformReferencev2__c = extractDetail(emailBody, '(?:Booking Reference:|Referencia de la reserva:)\\s*(\\S+)');
            if (relatedProduct != null) {
                booking.Product__c = relatedProduct.Id;
            }else{
                booking.ProductError__c = OrgUtils.reportProductError('Viator', productName, null, null, null, null,product);
            }
            String startDateTimeStr = extractDetail(emailBody, '(?:Travel Date:|Fecha del viaje:)\\s*(.*?)(?=Lead Traveler Name:)');
            String timeFromTourGrade = extractDetail(emailBody, '(?:Tour Grade Code:|Código de la categoría del tour:)\\s*\\S+~(\\d{2}:\\d{2})');
            
            if (String.isNotBlank(startDateTimeStr) && String.isNotBlank(timeFromTourGrade)) {
                try {
                    String[] dateParts = startDateTimeStr.split(','); 
                    if (dateParts.size() == 3) {
                        String monthDay = dateParts[1].trim(); 
                        String year = dateParts[2].trim();
                        String[] monthDayParts = monthDay.split(' '); 
                        
                        Integer month = getMonthNumber(monthDayParts[0]);
                        Integer day = Integer.valueOf(monthDayParts[1]);
                        
                        DateTime combinedDateTime = DateTime.newInstance(
                            Integer.valueOf(year),
                            month,
                            day,
                            Integer.valueOf(timeFromTourGrade.split(':')[0]),
                            Integer.valueOf(timeFromTourGrade.split(':')[1]),
                            0
                        );
                        
                        booking.StartDateTime__c = combinedDateTime;
                    } else {
                        System.debug('Invalid date format: ' + startDateTimeStr);
                    }
                } catch (Exception e) {
                    System.debug('Error parsing combined DateTime: ' + e.getMessage());
                }
            }
            
            
            booking.ContactFirstName__c = extractDetail(emailBody, '(?:Lead Traveler Name:|Nombre del viajero principal:)\\s*(.*?)(?=Traveler Names:|Nombres de los viajeros:)');
            String priceStr = extractDetail(emailBody, '(?:Net Rate:|Tarifa neta:)[\\s\\u00A0]*EUR[\\s\\u00A0]*€([\\d,\\.]+)');
            
            
            if (priceStr != null) {
                priceStr = priceStr.replace(',', '.'); 
                System.debug('Extracted Price: ' + priceStr);
            } else {
                System.debug('Price extraction failed.');
            }
            booking.TotalPrice__c = Decimal.valueOf(priceStr);
            booking.ContactPhone__c = extractDetail(emailBody, '(?:Phone:|Teléfono:)\\s*(.+?)\\s*(?=Send the customer|Envíe un mensaje al cliente)');
            booking.IntegrationPlatform__c = 'Viator';
            if (relatedContact != null) {
                booking.PrimaryContact__c = relatedContact.Id;
            }
            System.debug('booking.StartDateTime__c'+ booking.StartDateTime__c);
            insert booking;
            System.debug('Inserted Booking: ' + booking);
            List<String> travelerNames = new List<String>();
            String travelerNamesText = extractDetail(emailBody, '(?:Traveler Names:|Nombre del viajero principal:)(.*?)(?:Viajeros:|Travelers:)');
            if (String.isNotBlank(travelerNamesText)) {
                travelerNames.addAll(travelerNamesText.split(','));
            }
            System.debug('travelerNames: ' + travelerNames);
            
            List<Ticket__c> tickets = new List<Ticket__c>();
            
            for (Integer i = 0; i < travelerNames.size(); i++) {
                String travelerName = travelerNames[i].trim();
                
                Ticket__c ticket = new Ticket__c();
                ticket.Name = booking.PlatformReferencev2__c + ' - Entrada';
                ticket.Booking__c = booking.Id;
                ticket.OwnerName__c = travelerName;
                tickets.add(ticket);
                
            }
            
            
            if (!tickets.isEmpty()) {
                insert tickets;
            }
            
            result.success = true;
        } catch (Exception e) {
            System.debug('Error processing email: ' + e.getMessage());
            result.success = false;
        }
        
        return result;
    }
    
    
    private String extractDetail(String text, String regexPattern) {
        String sanitizedText = text.replace('*', '').replace('#', '');
        Pattern pattern = Pattern.compile(regexPattern);
        Matcher matcher = pattern.matcher(sanitizedText);
        if (matcher.find()) {
            return matcher.group(1).trim();
        }
        return null;
    }  
    
   
    
    private Integer getMonthNumber(String month) {
        Map<String, Integer> monthMap = new Map<String, Integer>{
            'Jan' => 1, 'Feb' => 2, 'Mar' => 3, 'Apr' => 4, 'May' => 5, 'Jun' => 6,
                'Jul' => 7, 'Aug' => 8, 'Sep' => 9, 'Oct' => 10, 'Nov' => 11, 'Dec' => 12
                };
                    return monthMap.get(month);
    }

    public static String convertDateFormat(String dateStr) {
        if (dateStr.contains('/')) {
            String[] parts = dateStr.split('/');

            if (Integer.valueOf(parts[0]) > 12) {
                return parts[2] + '-' + parts[1] + '-' + parts[0];
            } else if (Integer.valueOf(parts[1]) > 12) {
                return parts[2] + '-' + parts[0] + '-' + parts[1];
            }else{
                return parts[2] + '-' + parts[1] + '-' + parts[0];
            }

        } else if (dateStr.contains('-')) {
            return dateStr;

        } else {
            Map<String, String> months = new Map<String, String>{
                'JAN' => '01', 'FEB' => '02', 'MAR' => '03', 'APR' => '04',
                'MAY' => '05', 'JUN' => '06', 'JUL' => '07', 'AUG' => '08',
                'SEP' => '09', 'OCT' => '10', 'NOV' => '11', 'DEC' => '12'
            };
            String[] parts = dateStr.split(' ');
            if (parts.size() == 3 && months.containsKey(parts[0].toUpperCase())) {
                String month = months.get(parts[0].toUpperCase());
                String day = parts[1].length() == 1 ? '0' + parts[1] : parts[1];
                return parts[2] + '-' + month + '-' + day;
            }
        }
        return 'Formato no válido';
    }
    
}