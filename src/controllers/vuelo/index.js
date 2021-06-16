const { Pool } = require('pg');

const pool = new Pool({
    host: 'localhost',
    user: 'postgres',
    password: '13579',
    database: 'Aero',
    port: '5432'
});



const modificarPrecio = async (req, res) => { 
    /* 
       PUT/ body/raw
        {
        "IDVuelo":"3",
        "IDTipopasajero":"1",
        "Precio": "20"
        }
    */
    try {
        const  datos = req.body;
        const sql = ((`SELECT modificar_precio('${[JSON.stringify(datos)]}')`));
       
        const response = await pool.query(sql);
        res.status(200).json(response.rows[0].modificar_precio);
    
    } catch (error) {
        res.status(500).json(error);
    }
    
};



const obtenerVuelo = async (req, res) => {
    /*
    get/ params?IDVuelo=2
     */
    try {
        const  datos  = req.query;
        console.log(datos);
        const sql = ((`SELECT obtener_vuelo('${[datos.IDVuelo]}')`));
        console.log(sql);
    
      const response = await pool.query(sql);
        res.status(200).json(response.rows[0].obtener_vuelo);
       // console.log(response.rows[0].comandas_listar_tk)*/
    } catch (error) {
        res.status(500).json(error);
    }
    
};

 
 
module.exports = {
    modificarPrecio,
    obtenerVuelo

}