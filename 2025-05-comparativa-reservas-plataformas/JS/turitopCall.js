const SHORT_ID = 'TURITOP_SHORT_ID'; // Reemplaza con tu short_id
const SECRET  = '***'; // Reemplaza con tu secret_key
const yesterday = new Date();
yesterday.setDate(yesterday.getDate() - 1);
const dateFrom = Math.floor(yesterday.setHours(0, 0, 0, 0) / 1000); // Inicio de ayer en segundos
const dateTo = Math.floor(yesterday.setHours(23, 59, 59, 999) / 1000); // Fin de ayer en segundos

async function getoAuthToken(){
  const url = new URL('https://app.turitop.com/v1/authorization/grant');
  const bodyAuth = {
    "short_id": SHORT_ID,
    "secret_key": SECRET
  };
  try {
    const auth = await fetch(url, {
      method: 'POST',
      headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json'
      },
      body: JSON.stringify(bodyAuth)
    });

    if (!auth.ok) {
      const errorText = await auth.text();
      throw new Error(`Error ${auth.status}: ${auth.statusText}`);
    }

    const authResponse = await auth.json();
    const accessToken = authResponse.data.access_token;

    //Llamo a funcion getBookings
    await getBookings(accessToken, dateFrom, dateTo);

  } catch (error) {
    console.error('Error al obtener las reservas:', error.message);
  }
}

async function getBookings(token, from, to) {
  const url = new URL('https://app.turitop.com/v1/booking/getbookings');
  const bodyBookingsT = {
    "access_token": token,
    "data": {
      "filter": {
        "bookings_date_from": "1747864800",
        "bookings_date_to": "1747951199",
        "show_prebookings": true,
        "show_deleted": true
        //"multi_product_short_id": ["XXXX-250522-39","XXXX-250522-37","XXXX-250522-36"]
      }
    }
  };
  try {
    const book = await fetch(url, {
      method: 'POST',
      headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json'
      },
      body: JSON.stringify(bodyBookingsT)
    });

    if (!book.ok) {
      throw new Error(`Error ${book.status}: ${book.statusText}`);
    }

    const bookings = await book.json();
    console.log('Reservas obtenidas:');
    bookings.data.bookings.forEach((booking, index) => {
    console.log(`Reserva ${index + 1}:`, booking);
  });
  } catch (error) {
    console.error('Error al obtener las reservas:', error.message);
  }
}


getoAuthToken();
// console.log(dateFrom + ' : ' + 1747778400);
// console.log(dateTo + ' : ' + 1747864799);
