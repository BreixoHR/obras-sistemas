<apex:page controller="ConteoRegiondoController" showHeader="false" sidebar="false">
    <style>
        .app-header {
            position: relative;
            background-color: #005A9C;
            color: white;
            padding: 0px;
            font-size: 1.6em;
            font-weight: bold;
            text-align: center;
            height: 80px;
            align-items: center;
            display: flex;
            justify-content: center;
        }
        .app-logo {
            background-color: tomato;
            position: absolute;
            display: flex;
            left: 0px;
            height: 80px;
            align-items: center;
            justify-content: center;
        }
        .app-logo img {
            padding-left: 20px;
            padding-right: 20px;
            height: 70px;
            filter: grayscale(100%) brightness(180%);
        }
        .app-title {
            margin: 0 auto;
        }
        .app-grid {
            display: flex;
            flex-wrap: wrap;
            margin: 20px;
        }
        .app-card {
            background: #F4F6F9;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            flex: 1 1 200px;
            margin: 10px;
            padding: 20px;
            text-align: center;
        }
        .app-card .title {
            color: #FF6F00;
            font-size: 1.4em;
            font-weight: bold;
            margin-bottom: 10px;
        }
        .app-card .value {
            color: #005A9C;
            font-size: 2.5em;
            font-weight: bold;
        }
        .tableClass {
            width: 100%;
            border-collapse: collapse;
        }
        .tableClass th,
        .tableClass td {
            font-size: 1.2em;
            border: 1px solid #ddd;
            padding: 6px 8px;
            text-align: center;
        }
        .odd {
            background-color: #e6e6e6;
        }
        .even {
            background-color: #ffffff;
        }
        .colorRaiz .pbSubheader {
            background-color: tomato;
        }
        .colorNormal .pbSubheader {
            background-color: black;
        }
    </style>
        <div class="app-header">
            <div class="app-logo"><img src="https://www.example.com/logo.png" /></div>
            <div class="app-title">Dashboards Comparativas Reservas</div>
        </div>
        
    <apex:pageBlock >
        <div class="colorRaiz">
            <apex:pageBlockSection title="Regiondo" columns="1" collapsible="true">
                
                    <!-- Header -->
                    <div class="app-header">
                        <div class="app-title">Regiondo vs Salesforce</div>
                    </div>
                
                    <!-- Resumen general -->
                    <div class="app-grid">
                        <div class="app-card">
                            <div class="title">Reservas en Regiondo</div>
                            <div class="value">{!regiondoCount}</div>
                        </div>
                        <div class="app-card">
                            <div class="title">Reservas en Salesforce (Regiondo)</div>
                            <div class="value">{!salesforceCount}</div>
                        </div>
                        <div class="app-card">
                            <div class="title">BookingID que no entraron a SalesForce</div>
                            <div class="value">{!onlyCount}</div>
                        </div>
                    </div>
                
                    <!-- Detalle por origen con desplegables -->
                    <apex:pageBlock title="Reservas en Regiondo que no Entraron en Salesforce --Ayer">
                        <div class="colorNormal">
                            <apex:repeat value="{!wrapperList}" var="w">
                                <apex:pageBlockSection rendered="{!w.refs.size > 0}" title="{!w.origin}" columns="1" collapsible="true">
                                    <apex:outputPanel rendered="{!w.refs.size > 0}">
                                        <table class="tableClass">
                                            <thead>
                                                <tr>
                                                    <th>Localizador</th>
                                                    <th>Fecha de reserva</th>
                                                </tr>
                                            </thead>
                                            <tbody>
                                                <apex:variable var="idx" value="{! -1 }" />
                                                <apex:repeat value="{!w.refs}" var="ref">
                                                    <apex:variable var="idx" value="{!idx + 1}" />
                                                    <tr class="{!IF(MOD(idx, 2) = 0, 'even', 'odd')}">
                                                        <td>{!ref}</td>
                                                        <td>
                                                            <apex:outputText value="{0,date,dd/MM/yyyy HH:mm}">
                                                                <apex:param value="{!w.dates[idx]}" />
                                                            </apex:outputText>
                                                        </td>
                                                    </tr>
                                                </apex:repeat>
                                            </tbody>
                                        </table>
                                    </apex:outputPanel>
                                </apex:pageBlockSection>
                            </apex:repeat>    
                        </div>
                    </apex:pageBlock>
            </apex:pageBlockSection>
        </div>
    </apex:pageBlock>

    <apex:pageBlock >
        <div class="colorRaiz">
            <apex:pageBlockSection title="Turitop" columns="1" collapsible="true">
                <!-- Header -->
                <div class="app-header">
                    <div class="app-title">Turitop vs Salesforce</div>
                </div>
            
                <!-- Resumen general -->
                <div class="app-grid">
                    <div class="app-card">
                        <div class="title">Reservas en Turitop</div>
                        <div class="value">{!turitopCount}</div>
                    </div>
                    <div class="app-card">
                        <div class="title">Reservas en Salesforce (Turitop)</div>
                        <div class="value">{!salesforceCountTuritop}</div>
                    </div>
                    <div class="app-card">
                        <div class="title">BookingID que no entraron a SalesForce</div>
                        <div class="value">{!onlyCountTuritop}</div>
                    </div>
                </div>
            
                <!-- Detalle por origen con desplegables -->
                <apex:pageBlock title="Reservas en Turitop que no Entraron en Salesforce --Ayer">
                    <div class="colorNormal">
                        <apex:pageBlockSection title="Turitop (Demo Tours)" columns="1" collapsible="true">
                                <apex:outputPanel >
                                    <table class="tableClass">
                                        <thead>
                                            <tr>
                                                <th>Localizador</th>
                                                <th>Nombre Producto</th>
                                                <th>Fecha de reserva</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            <apex:variable var="idx" value="{! -1 }" />
                                            <apex:repeat value="{!wrapperListTuritop}" var="w">
                                                <apex:variable var="idx" value="{!idx + 1}" />
                                                <tr class="{!IF(MOD(idx, 2) = 0, 'even', 'odd')}">
                                                    <td>{!w.bookingID}</td>
                                                    <td>{!w.prod}</td>
                                                    <td>
                                                        <apex:outputText value="{0,date,dd/MM/yyyy HH:mm}">
                                                            <apex:param value="{!w.dateProd}" />
                                                        </apex:outputText>
                                                    </td>
                                                </tr>
                                            </apex:repeat>
                                        </tbody>
                                    </table>
                                </apex:outputPanel>
                        </apex:pageBlockSection>
                    </div>
                </apex:pageBlock>
            </apex:pageBlockSection>
        </div>
    </apex:pageBlock>
</apex:page>