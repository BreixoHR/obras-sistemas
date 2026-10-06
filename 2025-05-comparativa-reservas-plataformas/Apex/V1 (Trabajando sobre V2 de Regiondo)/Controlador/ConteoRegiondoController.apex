public with sharing class ConteoRegiondoController {

    //********************************************************************************//
    //********************************************************************************//
    //********************************************************************************//
    //***********************      CONSTRUCTOR GENERAL     ***************************//
    //********************************************************************************//
    //********************************************************************************//
    //********************************************************************************//
    public ConteoRegiondoController() {

        //********************************************************************************//
        //***********************         ZONA REGIONDO        ***************************//
        //********************************************************************************//
        // 1) Totales y únicos
        ConteoRegiondo.ComparisonResult resultado =
            ConteoRegiondo.compareRegiondoWithSalesforce();

        regiondoCount   = resultado.regiondoCount;
        salesforceCount = resultado.salesforceCount;
        onlyInRegiondo  = resultado.onlyInRegiondo;  // Map<String, DateTime>
        onlyCount       = onlyInRegiondo.size();

        // 2) Distribuir únicos por origen — pasamos el conjunto de claves (reservas)
        regiondoByOrigin = ConteoRegiondo.getOnlyInRegiondoByOrigin(onlyInRegiondo.keySet());

        // 3) Construir lista de wrappers para Visualforce, ordenando por fecha
        wrapperList = new List<OriginWrapper>();
        for (ConteoRegiondo.Origin o : regiondoByOrigin.keySet()) {
            List<String> refs = regiondoByOrigin.get(o);
            List<DateTime> dates = new List<DateTime>();

            if (ConteoRegiondo.regiondoReferenceDatesByOrigin.containsKey(o)) {
                Map<String, DateTime> refDates = ConteoRegiondo.regiondoReferenceDatesByOrigin.get(o);
                for (String ref : refs) {
                    dates.add(refDates.get(ref));
                }
            }

            OriginWrapper w = new OriginWrapper(o.name(), refs, dates);

            ordenarPorFecha(w);  // <-- ordenamos aquí

            wrapperList.add(w);
        }

        //********************************************************************************//
        //***********************         ZONA TURITOP         ***************************//
        //********************************************************************************//


    // 1) Totales y únicos
        ConteoRegiondo.ComparisonResultTuritop resultadoTuritop =
            ConteoRegiondo.compareTuritopWithSalesforce();

        turitopCount   = resultadoTuritop.turitopCount;
        salesforceCountTuritop = resultadoTuritop.salesforceCount;
        onlyInTuritop  = resultadoTuritop.onlyInTuritop;  // Map<String, Map<String, DateTime>>
        onlyCountTuritop   = onlyInTuritop.size();

        // 3) Construir lista de wrappers para Visualforce, ordenando por fecha
        wrapperListTuritop = new List<OriginWrapperTuritop>();
        for (String bookingID : onlyInTuritop.keySet()) {
            Map<String, DateTime> refDates = onlyInTuritop.get(bookingID);
            for (String prod : refDates.keySet()) {
                DateTime dateProd = refDates.get(prod);
                OriginWrapperTuritop w = new OriginWrapperTuritop(bookingID, prod, dateProd);
                wrapperListTuritop.add(w);
            }
        }
        ordenarPorFechaTuritop();
    }






    //********************************************************************************//
    //********************************************************************************//
    //********************************************************************************//
    //***********************        ZONA REGIONDO         ***************************//
    //********************************************************************************//
    //********************************************************************************//
    //********************************************************************************//
    public Integer regiondoCount       { get; set; }
    public Integer salesforceCount     { get; set; }
    public Integer onlyCount           { get; set; }

    public Map<String, DateTime> onlyInRegiondo { get; set; }  // Map con fechas

    public Map<ConteoRegiondo.Origin, List<String>> regiondoByOrigin { get; set; }
    public List<OriginWrapper> wrapperList { get; set; }

    // Wrapper simple para mostrar todas las reservas únicas con su fecha
    public class ReservaConFecha {
        public String idReserva { get; set; }
        public DateTime fechaCompra { get; set; }

        public ReservaConFecha(String id, DateTime fecha) {
            this.idReserva = id;
            this.fechaCompra = fecha;
        }
    }

    // Wrapper por origen con fechas
    public class OriginWrapper {
        public String origin { get; set; }
        public List<String> refs { get; set; }
        public List<DateTime> dates { get; set; }

        public OriginWrapper(String o, List<String> r, List<DateTime> d) {
            this.origin = o;
            this.refs   = r;
            this.dates  = d;
        }
    }


    // Método privado para ordenar refs y dates por fecha ascendente (burbuja)
    private void ordenarPorFecha(OriginWrapper w) {
        Integer n = w.refs.size();
        for (Integer i = 0; i < n - 1; i++) {
            for (Integer j = i + 1; j < n; j++) {
                if (w.dates[i] > w.dates[j]) {
                    // Intercambiar fechas
                    DateTime tempDate = w.dates[i];
                    w.dates[i] = w.dates[j];
                    w.dates[j] = tempDate;

                    // Intercambiar referencias
                    String tempRef = w.refs[i];
                    w.refs[i] = w.refs[j];
                    w.refs[j] = tempRef;
                }
            }
        }
    }

    // Para Visualforce
    public List<OriginWrapper> getWrapperList() {
        return wrapperList;
    }

    // Lista sencilla de reservas únicas con fecha
    public List<ReservaConFecha> getReservasUnicasRegiondo() {
        List<ReservaConFecha> lista = new List<ReservaConFecha>();
        for (String id : onlyInRegiondo.keySet()) {
            lista.add(new ReservaConFecha(id, onlyInRegiondo.get(id)));
        }
        return lista;
    }






    //********************************************************************************//
    //********************************************************************************//
    //********************************************************************************//
    //***********************         ZONA TURITOP         ***************************//
    //********************************************************************************//
    //********************************************************************************//
    //********************************************************************************//

    public Integer turitopCount       { get; set; }
    public Integer salesforceCountTuritop    { get; set; }
    public Integer onlyCountTuritop           { get; set; }

    public Map<String, Map<String, DateTime>> onlyInTuritop { get; set; }  // Map con fechas

    public List<OriginWrapperTuritop> wrapperListTuritop { get; set; }


    public class OriginWrapperTuritop {
        public String bookingID { get; set; }
        public String prod { get; set; }
        public DateTime dateProd { get; set; }

        public OriginWrapperTuritop(String b, String n, DateTime d) {
            this.bookingID = b;
            this.prod = n;
            this.dateProd = d;
        }
    }
    
    private void ordenarPorFechaTuritop() {
        Integer n = wrapperListTuritop.size();
        for (Integer i = 0; i < n - 1; i++) {
            for (Integer j = i + 1; j < n; j++) {
                if (wrapperListTuritop[i].dateProd > wrapperListTuritop[j].dateProd) {
                    OriginWrapperTuritop temp = wrapperListTuritop[i];
                    wrapperListTuritop[i] = wrapperListTuritop[j];
                    wrapperListTuritop[j] = temp;
                }
            }
        }
    }


    // Para Visualforce
    public List<OriginWrapperTuritop> getWrapperListTuritop() {
        return wrapperListTuritop;
    }


    

}
