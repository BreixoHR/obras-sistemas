public class EmployeeService {
    // Clase interna para mapear los datos de la API
    public class Employee {
        public String nationalId;
        public String lastName;
        public String lastName2;
        public String firstName;

        public Employee(String nationalId, String lastName, String lastName2, String firstName) {
            this.nationalId = nationalId;
            this.lastName   = lastName;
            this.lastName2  = lastName2;
            this.firstName  = firstName;
        }
    }

    // Token de autorización y lista de IDs de compañías
    private static final String AUTH_TOKEN = '***';
    private static final List<String> COMPANY_IDS = new List<String>{
        '***',
        '***'
    };

    /**
     * Llama a la API, parsea y guarda los empleados en Empleado__c
     */
    public static void actualizarEmpleados() {
        List<Employee> apiEmployees = getEmployees();
        System.debug('API Employees total: ' + apiEmployees.size());
        if (apiEmployees.isEmpty()) return;

        // 1) Deduplicar empleados por nationalId
        Map<String, Employee> uniqueApiEmployees = new Map<String, Employee>();
        for (Employee e : apiEmployees) {
            uniqueApiEmployees.put(e.nationalId, e);
        }

        // 2) Recoger todos los NationalId de la API
        Set<String> nationalIds = new Set<String>();
        for (Employee e : uniqueApiEmployees.values()) {
            nationalIds.add(e.nationalId);
        }

        // 3) Traer registros existentes de Empleado__c por NationalId__c
        Map<String, Empleado__c> existingMap = new Map<String, Empleado__c>();
        for (Empleado__c rec : [
            SELECT Id, NationalId__c, FirstName__c, LastName__c, LastName2__c
            FROM Empleado__c
            WHERE NationalId__c IN :nationalIds
        ]) {
            existingMap.put(rec.NationalId__c, rec);
        }

        // 4) Preparar listas para insert y update sin duplicados
        List<Empleado__c> toInsert = new List<Empleado__c>();
        List<Empleado__c> toUpdate = new List<Empleado__c>();
        Set<Id> seenIds = new Set<Id>();

        for (Employee e : uniqueApiEmployees.values()) {
            if (existingMap.containsKey(e.nationalId)) {
                Empleado__c rec = existingMap.get(e.nationalId);
                if (seenIds.add(rec.Id)) {
                    rec.FirstName__c  = e.firstName;
                    rec.LastName__c   = e.lastName;
                    rec.LastName2__c  = e.lastName2;
                    toUpdate.add(rec);
                }
            } else {
                toInsert.add(new Empleado__c(
                    NationalId__c = e.nationalId,
                    FirstName__c  = e.firstName,
                    LastName__c   = e.lastName,
                    LastName2__c  = e.lastName2
                ));
            }
        }

        // 5) Ejecutar DML
        if (!toInsert.isEmpty()) {
            insert toInsert;
            System.debug('Inserted: ' + toInsert.size());
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
            System.debug('Updated: ' + toUpdate.size());
        }
    }

    /**
     * Llama a la API de TramitApp para cada companyId y parsea la lista de empleados
     */
    public static List<Employee> getEmployees() {
        List<Employee> allEmployees = new List<Employee>();
        Http http = new Http();

        for (String companyId : COMPANY_IDS) {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://rrhh.example.com/tramitapi/' + companyId + '/employees');
            req.setMethod('GET');
            req.setHeader('auth', AUTH_TOKEN);

            try {
                HttpResponse res = http.send(req);
                if (res.getStatusCode() == 200) {
                    List<Object> employeesList = (List<Object>) JSON.deserializeUntyped(res.getBody());
                    System.debug('Company ' + companyId + ' returned ' + employeesList.size() + ' employees');
                    for (Object empObj : employeesList) {
                        Map<String, Object> empMap = (Map<String, Object>) empObj;
                        allEmployees.add(new Employee(
                            (String) empMap.get('nationalId'),
                            (String) empMap.get('lastName'),
                            (String) empMap.get('lastName2'),
                            (String) empMap.get('firstName')
                        ));
                    }
                } else {
                    System.debug('HTTP error [' + res.getStatusCode() + '] for company ' + companyId + ': ' + res.getBody());
                }
            } catch (Exception ex) {
                System.debug('Exception for company ' + companyId + ': ' + ex.getMessage());
            }
        }
        return allEmployees;
    }
}
