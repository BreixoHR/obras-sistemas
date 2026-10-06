<apex:page controller="DynamicButtonsController" showHeader="false" sidebar="false">
    <style>
        /* === HEADER Y LOGO (sin tocar) === */
        .app-header {
            background-color: #005A9C;
            color: white;
            font-size: 1.6em;
            font-weight: bold;
            height: 80px;
            display: flex;
            align-items: center;
            justify-content: center;
            position: relative;
            box-shadow: 0 2px 6px rgb(0 0 0 / 0.15);
        }
        .app-logo {
            position: absolute;
            left: 10px;
            height: 80px;
            display: flex;
            align-items: center;
        }
        .app-logo img {
            height: 70px;
            padding: 0 20px;
            filter: grayscale(100%) brightness(180%);
        }
        .app-title {
            flex-grow: 1;
            text-align: center;
        }

        /* === GLOBAL BOTONES EN NARANJA === */
        apex\\:commandButton,
        button,
        input[type="submit"],
        input[type="button"],
        input[type="reset"] {
            background-color: #FF6A00 !important;
            color: white !important;
            border: none !important;
            padding: 10px 22px !important;
            font-weight: 600 !important;
            border-radius: 8px !important;
            box-shadow: 0 4px 12px rgb(255 106 0 / 0.4) !important;
            cursor: pointer !important;
            transition: background-color 0.25s ease, box-shadow 0.25s ease !important;
            font-size: 1.05em !important;
            margin: 6px 4px !important;
            display: inline-block !important;
            text-transform: uppercase !important;
            letter-spacing: 0.05em !important;
        }
        apex\\:commandButton:hover,
        button:hover,
        input[type="submit"]:hover,
        input[type="button"]:hover,
        input[type="reset"]:hover {
            background-color: #e65a00 !important;
            box-shadow: 0 6px 16px rgb(230 90 0 / 0.55) !important;
        }

        /* === INPUTS Y SELECTS ESTILO NARANJA === */
        input[type="text"],
        input[type="date"],
        apex\\:inputText input,
        select,
        apex\\:selectList select {
            width: 100%;
            padding: 10px 14px;
            border: 2px solid #ffb980;
            border-radius: 8px;
            font-size: 1em;
            transition: border-color 0.3s ease, box-shadow 0.3s ease;
            box-sizing: border-box;
            outline-offset: 3px;
            background-color: #fff6ec;
            color: #663300;
            font-weight: 600;
            font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
            appearance: none;
            background-image: url("data:image/svg+xml;charset=US-ASCII,%3csvg%20width%3d%2210%22%20height%3d%227%22%20viewBox%3d%220%200%2010%207%22%20fill%3d%22none%22%20xmlns%3d%22http%3a//www.w3.org/2000/svg%22%3e%3cpath%20d%3d%22M0.833252%200.999969L5.00058%206.1663L9.16791%200.999969H0.833252Z%22%20fill%3d%22%23FF6A00%22/%3e%3c/svg%3e");
            background-repeat: no-repeat;
            background-position: right 12px center;
            background-size: 10px 7px;
        }
        input[type="text"]:focus,
        input[type="date"]:focus,
        apex\\:inputText input:focus,
        select:focus,
        apex\\:selectList select:focus {
            border-color: #FF6A00;
            box-shadow: 0 0 8px #FF6A00aa;
            outline: none;
            background-color: white;
            color: #a64c00;
        }

        /* === TABLA MODERNIZADA === */
        .app-table {
            width: 100%;
            border-collapse: separate;
            border-spacing: 0 8px;
            margin-top: 10px;
            font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
            color: #663300;
        }
        .app-table thead th {
            background: linear-gradient(135deg, #FF6A00, #e65a00);
            color: white;
            font-weight: 700;
            padding: 16px 14px;
            border-radius: 12px 12px 0 0;
            text-align: center;
            letter-spacing: 0.1em;
            text-transform: uppercase;
            box-shadow: 0 4px 8px rgb(255 106 0 / 0.4);
            border-bottom: 3px solid #cc5800;
            font-size: 1.1em;
        }
        .app-table tbody tr {
            background-color: #fff6ec;
            box-shadow: 0 1px 5px rgb(255 106 0 / 0.15);
            border-radius: 8px;
            transition: background-color 0.3s ease;
        }
        .app-table tbody tr:hover {
            background-color: #ffe7cc;
        }
        .app-table tbody tr td {
            padding: 12px 14px;
            border-bottom: none;
            text-align: center;
            font-size: 1em;
            font-weight: 600;
        }
        .app-table tbody tr:nth-child(even) {
            background-color: #ffefd6;
        }
        .app-table tbody tr td apex\\:commandButton {
            background-color: #d64541;
            box-shadow: none;
            padding: 7px 13px;
            font-weight: 700;
            border-radius: 50%;
            width: 34px;
            height: 34px;
            line-height: 18px;
            text-align: center;
            color: white !important;
            font-size: 1.2em;
        }
        .app-table tbody tr td apex\\:commandButton:hover {
            background-color: #a3322e;
            box-shadow: 0 0 10px #a3322ecc;
        }

        /* === TÍTULO LLAMATIVO Y CONTADOR === */
        .selected-guide-title {
            font-size: 1.5em;
            font-weight: 900;
            color: #FF6A00;
            text-shadow: 1px 1px 4px #e65a00bb;
            margin: 20px 0 10px;
            font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
        }
        .table-counter-wrapper {
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 20px;
        }
        .tour-counter {
            font-size: 1.1em;
            font-weight: 700;
            color: #FF6A00;
            padding: 6px 12px;
            border-radius: 12px;
            background: linear-gradient(135deg, #fff2e6, #ffb366);
            box-shadow: 0 3px 6px #ff9b1e88;
            font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
        }

        /* Quitar bordes de pageBlock para limpieza */
        apex\\:pageBlock,
        apex\\:pageBlockSection {
            border: none !important;
            box-shadow: none !important;
            padding: 0 !important;
            margin-bottom: 20px;
        }
    </style>

    <div class="app-header">
        <div class="app-logo">
            <img src="https://www.example.com/logo.png" />
        </div>
        <div class="app-title">Gestión de Guías - Demo Tours</div>
    </div>

    <apex:form >
        <apex:pageBlock title="Gestión de Guías">
            <apex:pageBlockSection title="Registrar un Guía" columns="2">
               <apex:inputText value="{!newTableName}" label="Nombre del Guía"/>
               <apex:commandButton value="Registrar" action="{!addTable}" reRender="mainPanel"/>
            </apex:pageBlockSection>

            <apex:pageBlockSection id="mainPanel" title="Guías existentes" columns="1">
                <div class="app-buttons">
                    <apex:repeat value="{!tableNames}" var="t">
                        <apex:commandButton value="{!t}" action="{!selectTable}" reRender="rowsPanel">
                            <apex:param name="tableNameParam" value="{!t}" assignTo="{!selectedTableName}"/>
                        </apex:commandButton>
                    </apex:repeat>
                </div>
            </apex:pageBlockSection>

            <apex:pageBlockSection title="Detalle del Guía" id="rowsPanel" columns="1">
                <apex:outputPanel rendered="{!NOT(ISNULL(selectedTableName))}">
                    <div class="selected-guide-title">
                        Tours del guía seleccionado: <strong>{!selectedTableName}</strong>
                    </div>

                    <div class="date-filter">
                        <span>
                            <label for="fechaInicio">Fecha Inicio:</label>
                            <apex:inputText id="fechaInicio" value="{!fechaInicio}" html-type="date"/>
                        </span>
                        <span>
                            <label for="fechaFin">Fecha Fin:</label>
                            <apex:inputText id="fechaFin" value="{!fechaFin}" html-type="date"/>
                        </span>
                    </div>

                    <div class="table-counter-wrapper">
                        <table class="app-table">
                            <thead>
                                <tr>
                                    <th>Fecha del Tour</th>
                                    <th>Idioma del Tour</th>
                                    <th>Pax</th>
                                    <th>Borrar Tour</th>
                                </tr>
                            </thead>
                            <tbody>
                                <apex:variable var="rowIndex" value="0"/>
                                <apex:repeat value="{!rows}" var="row">
                                    <tr>
                                        <td><apex:inputField value="{!row.Fecha_Hora__c}"/></td>
                                        <td><apex:inputField value="{!row.Guia__c}"/></td>
                                        <td><apex:inputField value="{!row.Horas__c}"/></td>
                                        <td>
                                            <apex:commandButton value="X" action="{!removeRow}" reRender="rowsPanel" title="Eliminar fila">
                                                <apex:param name="rowIndex" value="{!rowIndex}" assignTo="{!rowToDeleteIndex}"/>
                                            </apex:commandButton>
                                        </td>
                                    </tr>
                                    <apex:variable var="rowIndex" value="{!VALUE(rowIndex) + 1}"/>
                                </apex:repeat>
                            </tbody>
                        </table>

                        <div class="tour-counter">
                            Total tours: {!rows.size}
                        </div>
                    </div>

                    <apex:commandButton value="Agregar Tour" action="{!addRow}" reRender="rowsPanel"/>
                    <apex:commandButton value="Guardar cambios" action="{!saveRows}" reRender="rowsPanel"/>
                    <apex:commandButton value="Descargar Informe del guía"
                                        action="{!downloadCsv}"
                                        immediate="true"
                                        reRender="none"/>
                </apex:outputPanel>
            </apex:pageBlockSection>
        </apex:pageBlock>
    </apex:form>
</apex:page>