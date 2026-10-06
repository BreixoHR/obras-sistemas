public with sharing class DynamicButtonsController {

    public String newTableName { get; set; }
    public String selectedTableName { get; set; }
    public List<String> tableNames { get; set; }
    public List<DynamicTableRow__c> rows { get; set; }
    public Date fechaInicio { get; set; }
    public Date fechaFin { get; set; }
    public Integer rowToDeleteIndex { get; set; }


    public DynamicButtonsController() {
        loadTableNames(); // carga desde BD
        rows = new List<DynamicTableRow__c>();
    }

    public void loadTableNames() {
        tableNames = new List<String>();
        List<AggregateResult> results = [
            SELECT TableName__c FROM DynamicTableRow__c
            WHERE TableName__c != null
            GROUP BY TableName__c
            ORDER BY TableName__c
        ];

        for (AggregateResult ar : results) {
            String name = (String) ar.get('TableName__c');
            tableNames.add(name);
        }
    }

    public void addTable() {
        if (String.isBlank(newTableName)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Debe ingresar un nombre para la tabla'));
            return;
        }

        // Solo si no existe ya una tabla con ese nombre
        if (!tableNames.contains(newTableName)) {
            DynamicTableRow__c dummyRow = new DynamicTableRow__c();
            dummyRow.TableName__c = newTableName;
            dummyRow.Guia__c = 'Inicial'; // Campo obligatorio
            insert dummyRow;
        }

        selectedTableName = newTableName;
        loadTableNames(); // recargar botones
        loadRows();       // cargar filas si ya tenía
        newTableName = null;
    }

    public void selectTable() {
        loadRows();
    }

    public void loadRows() {
        if (String.isBlank(selectedTableName)) {
            rows = new List<DynamicTableRow__c>();
        } else {
            rows = [
                SELECT Id, Fecha_Hora__c, Guia__c, Horas__c, TableName__c
                FROM DynamicTableRow__c
                WHERE TableName__c = :selectedTableName
                ORDER BY Fecha_Hora__c ASC NULLS LAST
            ];
        }
    }

    public void addRow() {
        if (String.isBlank(selectedTableName)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Seleccione una tabla primero'));
            return;
        }
        DynamicTableRow__c newRow = new DynamicTableRow__c();
        newRow.TableName__c = selectedTableName;
        newRow.Guia__c = 'Pendiente'; // para evitar error de campo obligatorio
        insert newRow;
        loadRows();
    }

    public void saveRows() {
        try {
            update rows;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM, 'Cambios guardados correctamente'));
            loadRows();
        } catch (DmlException e) {
            ApexPages.addMessages(e);
        }
    }
    


public void removeRow() {
    if (rowToDeleteIndex != null && rowToDeleteIndex >= 0 && rowToDeleteIndex < rows.size()) {
        // Obtener el registro a borrar
        DynamicTableRow__c rowToDelete = rows[rowToDeleteIndex];
        try {
            delete rowToDelete;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM, 'Tour eliminado correctamente'));
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error al eliminar el tour: ' + e.getMessage()));
        }
    }
    // Recargar la lista para reflejar los cambios
    loadRows();
}
public PageReference downloadCsv() {
    // 1) Validaciones
    if (String.isBlank(selectedTableName)) {
        ApexPages.addMessage(new ApexPages.Message(
            ApexPages.Severity.ERROR,
            'Seleccione una tabla para descargar'
        ));
        return null;
    }
    if (fechaInicio != null && fechaFin != null && fechaInicio > fechaFin) {
        ApexPages.addMessage(new ApexPages.Message(
            ApexPages.Severity.ERROR,
            'La fecha de inicio no puede ser posterior a la fecha de fin.'
        ));
        return null;
    }

    // 2) Calcular fechaFinDT al final del día
    DateTime fechaFinDT = null;
    if (fechaFin != null) {
        fechaFinDT = DateTime.newInstance(fechaFin, Time.newInstance(23, 59, 59, 999));
    }

    // 3) Cargar los registros según filtros
    List<DynamicTableRow__c> exportRows;
    if (fechaInicio != null && fechaFinDT != null) {
        exportRows = [
            SELECT Fecha_Hora__c, Guia__c, Horas__c
            FROM DynamicTableRow__c
            WHERE TableName__c = :selectedTableName
              AND Fecha_Hora__c >= :fechaInicio
              AND Fecha_Hora__c <= :fechaFinDT
            ORDER BY Fecha_Hora__c ASC NULLS LAST
        ];
    } else if (fechaInicio != null) {
        exportRows = [
            SELECT Fecha_Hora__c, Guia__c, Horas__c
            FROM DynamicTableRow__c
            WHERE TableName__c = :selectedTableName
              AND Fecha_Hora__c >= :fechaInicio
            ORDER BY Fecha_Hora__c ASC NULLS LAST
        ];
    } else if (fechaFinDT != null) {
        exportRows = [
            SELECT Fecha_Hora__c, Guia__c, Horas__c
            FROM DynamicTableRow__c
            WHERE TableName__c = :selectedTableName
              AND Fecha_Hora__c <= :fechaFinDT
            ORDER BY Fecha_Hora__c ASC NULLS LAST
        ];
    } else {
        exportRows = [
            SELECT Fecha_Hora__c, Guia__c, Horas__c
            FROM DynamicTableRow__c
            WHERE TableName__c = :selectedTableName
            ORDER BY Fecha_Hora__c ASC NULLS LAST
        ];
    }

    // 4) Construir el CSV en un String
    String csv = 'Fecha_Hora__c,Guia__c,Horas__c\n';
    for (DynamicTableRow__c row : exportRows) {
        String fecha = row.Fecha_Hora__c != null
            ? row.Fecha_Hora__c.format('yyyy-MM-dd HH:mm:ss')
            : '';
        String guia = row.Guia__c != null
            ? '"' + row.Guia__c.replace('"','""') + '"'
            : '';
        String horas = row.Horas__c != null
            ? String.valueOf(row.Horas__c)
            : '';
        csv += fecha + ',' + guia + ',' + horas + '\n';
    }

    // 5) Codificar en Base64 y montar Data URI
    Blob csvBlob = Blob.valueOf(csv);
    String base64 = EncodingUtil.base64Encode(csvBlob);
    String dataUri = 'data:text/csv;base64,' + base64;

    // 6) Redirigir a esa URI para forzar la descarga
    PageReference download = new PageReference(dataUri);
    download.setRedirect(true);
    return download;
}



}