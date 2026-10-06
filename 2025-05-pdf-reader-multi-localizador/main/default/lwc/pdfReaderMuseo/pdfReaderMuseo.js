import { LightningElement, api, wire } from 'lwc';
import pdfjs from '@salesforce/resourceUrl/pdfjs';
import { loadScript } from 'lightning/platformResourceLoader';
import { RefreshEvent } from 'lightning/refresh';
import getPdfBase64 from '@salesforce/apex/PdfFilesUpdater.getPdfBase64';
import saveBookingDate from '@salesforce/apex/PdfFilesUpdater.saveBookingDate';
import isPdfFieldEmpty from '@salesforce/apex/PdfFilesUpdater.isPdfFieldEmpty';
import saveLocalizador from '@salesforce/apex/PdfFilesUpdater.saveLocalizador';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class PdfReaderMuseo extends LightningElement {
    @api recordId; //Registro asociado con Booking__c
    pdfData = null;//Guarda la referencia a la librería PDFjs Dinamicamente
    pdfjsLib = null;
    showComponent = false; //Sin uso (Comentado) 
   

    @wire(isPdfFieldEmpty, { bookingId: '$recordId' })//En este bloque verificamos si el campo PDF está vacío
        checkPdfField({ error, data }) {              //IMPORTANTE El campo PDF del booking es el que activa o no el procesamiento.
            console.log('recordId:', this.recordId);
            console.log('Wire data:', data);
            console.log('Wire error:', error); 

            if (data !== undefined) {
               // console.log('PDF__c field is:', data ? 'empty' : 'not empty');
               // this.showComponent = data; 
               // if (this.showComponent) {
                this.loadPdfJsLibrary();
                
            } else if (error) {
                console.error('Error fetching PDF__c field:', error);
            }
        }

        loadPdfJsLibrary() {                          //Aqui se carga la librería PDF.js
            Promise.all([
                loadScript(this, pdfjs + '/pdf.js'),
                loadScript(this, pdfjs + '/pdf.worker.js')
            ])
                .then(() => {
                    this.pdfjsLib = window.pdfjsLib;
                    console.log('pdf.js and pdf-lib loaded:', this.pdfjsLib);
                    this.pdfjsLib.GlobalWorkerOptions.workerSrc = pdfjs + '/pdf.worker.js';
                    console.log('pdfjsLib.GlobalWorkerOptions.workerSrc', this.pdfjsLib.GlobalWorkerOptions.workerSrc);
                    this.fetchPdfFromApex();  //LLamamos a la funcion que obtiene el pdf desde APEX
                })
                .catch(error => {
                    console.error('Error loading scripts: ' + error);
                });
        }

    async fetchPdfFromApex() {                      //Aquí obtenemos el PDF de APEX, salesforce
        try {
            const base64Pdf = await getPdfBase64({ bookingId: this.recordId }); //getPdfBase64 esta es la libreía que obtiene el pdf en base 64
            console.log('Base64 PDF from Apex:', base64Pdf); 
            this.processPdf(base64Pdf); 
        } catch (error) {
            console.error('Error fetching PDF from Apex:', error);
        }
    }

    base64ToBytes(base64) { //Transforma el string base64 a una secuencia de bytes para que PDF.js lo pueda leer
        const binaryString = atob(base64); 
        return Uint8Array.from(binaryString, char => char.charCodeAt(0)); 
    }

    async processPdf(base64Pdf) {
        try {
            const pdfData = this.base64ToBytes(base64Pdf); //Aqui analizamos el PDF en array de bytes
            console.log('Converted PDF Data (byte array):', pdfData);
                
            console.log('this.pdfjsLib:', this.pdfjsLib);
            console.log('this.pdfjsLthis.pdfjsLib.getDocument({ data: pdfData })ib:', this.pdfjsLib.getDocument({ data: pdfData })); //Se guarda el pdf en la variable data, en array de bytes
            const loadingTask = pdfjsLib.getDocument({ data: pdfData });
            console.log('loadingTask:', loadingTask);
            console.log('loadingTask.promise:', loadingTask.promise);
            const pdf = await loadingTask.promise;
            console.log('pdf:', pdf);
            console.log('PDF loaded');
            console.log('Number of Pages:', pdf.numPages);

            const months = {
                enero: 0, febrero: 1, marzo: 2, abril: 3, mayo: 4, junio: 5,
                julio: 6, agosto: 7, septiembre: 8, octubre: 9, noviembre: 10, diciembre: 11
            };

            let fechaVisita = null;
            let localizador = null;
            for (let i = 1; i <= pdf.numPages; i++) {   //Iniciamos el loop para averiguar cuantas páginas hay en el pdf y el contenido de cada una por separado
                const page = await pdf.getPage(i);
                console.log('Page:', i);
                const textContent = await page.getTextContent();
                const text = textContent.items.map(item => item.str).join(' ');
                console.log(`Text on Page ${i}:`, text);
                let fechaMatch = text.match(/Monumento\s+(\d{2}[\/-]\d{2}[\/-]\d{2,4})/);
                if (!fechaMatch) {
                    fechaMatch = text.match(/\d{1,2} de [a-z]+ de \d{4}(?!\s*Fecha de compra:)/gi);
                }
                if (!fechaMatch) {
                    fechaMatch = text.match(/(\d{1,2}[\/-]\d{1,2}[\/-]\d{2,4})/);
                }
                if (!fechaMatch) {
                    fechaMatch = text.match(/(?:\w+, )?(\d{1,2})\s+([a-zA-ZñÑ]+)\s+(\d{4})/);
                }

                if (text.includes('museo')) { // Verifica si el PDF es del Museo
                    const match = text.match(/Identificador\s*([\w\-]+)/i); // Busca lo que está debajo de "Identificador"
                    if (match) {
                        localizadorMuseo = match[1]; // Guarda el valor 
                        console.log('Identificador capturado:', localizadorMuseo);
                    }
                }   
                // let localizadorMuseo;
                // if(text.includes('museo')){ //Verifica si la palabra "museo" aparece dentro del texto extraído de una página del PDF.
                    // localizadorMuseo = text.match(/LOCALIZADOR\s+([A-Z0-9]+)/i);//Busca un texto que diga algo como "LOC. RESERVA: ABC123
                // }    

                if (fechaMatch && !localizadorMuseo) {
                    fechaVisita = this.extractAndFormatFecha(fechaMatch);
                    console.log('fecha visita:', fechaVisita);
                }else if(localizadorMuseo && fechaMatch){
                    fechaVisita = this.extractAndFormatFecha(fechaMatch);
                    localizador = localizadorMuseo[1];
                    console.log('Localizador:', localizador);
                }
            }

            if(fechaVisita && localizador){
                this.saveLocalizadorMuseo(localizador, fechaVisita);
            }else if(fechaVisita){
                this.saveFechaVisita(fechaVisita);
            }

        } catch (error) {
            console.error('Error processing PDF:');
            console.error(error); 
            console.error(error.message); 
            console.error(error.name); 
            console.error(error.stack);
        }
    }

    formatearFecha(fecha) {
        const anio = fecha.getFullYear();
        const mes = String(fecha.getMonth() + 1).padStart(2, '0'); // Añade un 0 si es necesario
        const dia = String(fecha.getDate()).padStart(2, '0'); // Añade un 0 si es necesario
        return `${dia}/${mes}/${anio}`;
    }
    
    async saveFechaVisita(fechaVisita) {
        try {
            const refresh = await saveBookingDate({ bookingId: this.recordId, fechaVisita });
            if(refresh){
                this.dispatchEvent(new RefreshEvent());
            }
            console.log('Fecha de visita saved successfully');
        } catch (error) {
            console.error('Error saving Fecha de visita:', error);
        }
    }

    async saveLocalizadorMuseo(localizadorMuseo, fechaVisita) {
        try{
            const continueSaving = await saveLocalizador({ localizador: localizadorMuseo, bookingId : this.recordId });
            if(continueSaving){
                const refresh = await saveBookingDate({ bookingId: this.recordId, fechaVisita });
                if(refresh){
                    this.dispatchEvent(new RefreshEvent());
                }
            }else{
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Archivo eliminado',
                        message: 'El ticket subido se eliminó ya que se encontró una reserva con ese localizador',
                        variant: 'warning',
                        mode: 'dismissable'
                    })
                );
                this.dispatchEvent(new RefreshEvent());
            }
        } catch (error) {
            console.error('Error saving Localizador:', error);
        }
    }

    extractAndFormatFecha(fechaMatch) {
        let fechaVisita;
        if (fechaMatch.length === 4) {
            const day = parseInt(fechaMatch[1], 10);
            const monthName = fechaMatch[2].toLowerCase();
            const year = parseInt(fechaMatch[3], 10);

            const month = months[monthName];

            if (month !== undefined) {
                fechaVisita = this.formatearFecha(new Date(year, month, day));
            } else {
                console.error('Invalid month name:', monthName);
            }

        } else if(fechaMatch[0].includes("de")){
            const [day, monthName, year] = fechaMatch[0].split(" de ");
            const month = months[monthName];
            if (month !== undefined) {
                fechaVisita = this.formatearFecha(new Date(year, month, day));
            } else {
                console.error('Invalid month name:', monthName);
            }
        } else {
            fechaVisita = fechaMatch[1];
        }
        return fechaVisita;
    }
}