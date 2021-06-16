const { Router } = require("express");
const router = Router();
 
const { nuevaReserva,obtenerReserva,listarReservas } = require("../controllers/reserva");
const { modificarPrecio,obtenerVuelo } = require("../controllers/vuelo");

//Reserva
router.post('/reserva/nueva',nuevaReserva);
router.get('/reserva',obtenerReserva);
router.get('/reservas',listarReservas);

//Vuelo
router.put('/vuelo/modificarPrecio',modificarPrecio);
router.get('/vuelo',obtenerVuelo);



module.exports = router;