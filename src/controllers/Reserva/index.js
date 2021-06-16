const { Pool } = require('pg');

const pool = new Pool({
    host: 'localhost',
    user: 'postgres',
    password: '13579',
    database: 'Aero',
    port: '5432'
});



const nuevaReserva = async (req, res) => { 
    /*
            post/ body/raw
        {
        "IDVuelo":"3",
        "Cliente":"ANGEL LABORI",
        "Detalle":[
                {
                    "IDTipoPasajero":"1",
                    "Cantidad":"2"
                },
                {
                    "IDTipoPasajero":"2",
                    "Cantidad":"2"
                }
            ]
        }
    */
    try {
        const  datos = req.body;
        const sql = ((`SELECT nueva_reserva('${[JSON.stringify(datos)]}')`));
        console.log(sql);
        const response = await pool.query(sql);
        res.status(200).json(response.rows[0].nueva_reserva);
        console.log(response.rows[0].nueva_reserva)
    } catch (error) {
        res.status(500).json(error);
    }
    
};




const obtenerReserva = async (req, res) => {
    /* 
       get/ params?IDReserva=2
    */
    try {
        const  datos  = req.query;
        console.log(datos);
        const sql = ((`SELECT obtener_reserva('${[datos.IDReserva]}')`));
        console.log(sql);
    
      const response = await pool.query(sql);
        res.status(200).json(response.rows[0].obtener_reserva);
       // console.log(response.rows[0].comandas_listar_tk)*/
    } catch (error) {
        res.status(500).json(error);
    }
    
};



const listarReservas = async (req, res) => {
    /* 
       get/ body/raw
        {
            "AeropuertoSalida":"-1",
            "AeropuertoLlegada":"-1",
            "Fecha":"19900101",
            "Areolinea":"-1",
            "NumeroVuelo":"A"
            
        }
    */
    try {
        const  datos  = req.body;
        console.log(req.body)
        console.log(datos);
        const sql = ((`SELECT listar_reservas('${[JSON.stringify(datos)]}')`));
        console.log(sql);
      const response = await pool.query(sql);
        res.status(200).json(response.rows[0].listar_reservas);
       // console.log(response.rows[0].comandas_listar_tk)*/
    } catch (error) {
        res.status(500).json(error);
    }
    
};
 
module.exports = {
    nuevaReserva,
    obtenerReserva,
    listarReservas

}