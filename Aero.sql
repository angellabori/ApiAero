 -- Database: "Aero"

-- DROP DATABASE "Aero";

CREATE DATABASE "Aero"
  WITH OWNER = postgres
       ENCODING = 'UTF8'
       TABLESPACE = pg_default
       LC_COLLATE = 'Spanish_Venezuela.1252'
       LC_CTYPE = 'Spanish_Venezuela.1252'
       CONNECTION LIMIT = -1;


--
-- TOC entry 1 (class 3079 OID 12355)
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- TOC entry 2182 (class 0 OID 0)
-- Dependencies: 1
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- TOC entry 209 (class 1255 OID 1176866)
-- Name: listar_reservas(json); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION listar_reservas(json_entrada json) RETURNS json
    LANGUAGE plpgsql
    AS $$ 
 
BEGIN
  
	return  (coalesce((
	
		select array_to_json(array_agg(row_to_json(t))) from (
			select r.*,v.fecha fecha_salida ,v.hora_salida,v.hora_llegada,v.numero_vuelo ,a1.nombre aeropuerto_salida,a2.nombre aeropuerto_llegada, a.nombre aerolinea,
				coalesce((
				select array_to_json(array_agg(row_to_json(t)))from (

					select rd.*,tp.descripcion tipo_pasajero from reserva_detalle rd
					inner join tipo_pasajero tp on tp.id = rd.id_tipo_pasajero
					where id_reserva = r.id
					
				)t),'[]') Detalles

			 from reserva r
			 inner join vuelo v on v.id = r.id_vuelo
			 inner join aeropuerto a1 on a1.id = v.id_aeropuerto_salida
			 inner join aeropuerto a2 on a2.id = v.id_aeropuerto_llegada
			 inner join aerolinea a on a.id = v.id_areolinea
			 where  (a1.id =  cast(json_entrada->>'AeropuertoSalida' as int)   or  cast(json_entrada->>'AeropuertoSalida' as int) = -1)
			 and (a2.id =  cast(json_entrada->>'AeropuertoLlegada' as int)   or  cast(json_entrada->>'AeropuertoLlegada' as int) = -1)
			 and (v.fecha =  cast(json_entrada->>'Fecha' as date)   or  cast(json_entrada->>'Fecha' as date) = '19900101')
			 and (v.id_areolinea   =  cast(json_entrada->>'Areolinea' as int)   or  cast(json_entrada->>'Areolinea' as int) = -1)
			 and (v.numero_vuelo  like  '%' || cast(json_entrada->>'NumeroVuelo' as text) || '%'   or  cast(json_entrada->>'NumeroVuelo' as text) = '')
		)t),'[]')  
	);
 
END;
$$;


ALTER FUNCTION public.listar_reservas(json_entrada json) OWNER TO postgres;

--
-- TOC entry 207 (class 1255 OID 1176867)
-- Name: modificar_precio(json); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION modificar_precio(json_entrada json) RETURNS json
    LANGUAGE plpgsql
    AS $$  
BEGIN
--Validadcion si existe el vuelo
if exists (select * from vuelo where id = cast(json_entrada->>'IDVuelo' as int)) then  
	if exists (select * from vuelo_precio where id_tipo_pasajero = cast(json_entrada->>'IDTipopasajero' as int) and id_vuelo = cast(json_entrada->>'IDVuelo' as int)) then  
	  
		UPDATE vuelo_precio SET precio = cast(json_entrada->>'Precio' as numeric) 
		where  id_vuelo= cast(json_entrada->>'IDVuelo' as int) and  id_tipo_pasajero=cast(json_entrada->>'IDTipopasajero' as int);

		return '{ 
			"mensaje":"PRECIO ACTUALIZADO CON EXITO"
			}';	
		
	else
		return '{ 
			"mensaje":"NO EXISTE EL TIPO DE PASAJERO"
			}';	
	end if;
	
else
	return '{ 
		"mensaje":"NO EXISTE EL VUELO"
		}';	
end if;

END;
$$;


ALTER FUNCTION public.modificar_precio(json_entrada json) OWNER TO postgres;

--
-- TOC entry 208 (class 1255 OID 1176857)
-- Name: nueva_reserva(json); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION nueva_reserva(json_entrada json) RETURNS json
    LANGUAGE plpgsql
    AS $$ 
declare 
	v_reserva_id_seq int;
	v_detalle json;
	v_total numeric(18,2);
	v_precio numeric(18,2);
	v_cantidad_total int;
BEGIN
--Validadcion si existe el vuelo
if exists (select * from vuelo where id = cast(json_entrada->>'IDVuelo' as int)) then  
	v_cantidad_total = 0;
	v_total = 0;
	if (select json_array_length( json_entrada->'Detalle' )) > 0 then 
		FOR v_detalle IN SELECT * FROM json_array_elements( json_entrada->'Detalle')  LOOP
			v_precio = (select precio from vuelo_precio where id_vuelo = cast(json_entrada->>'IDVuelo' as int) and id_tipo_pasajero = cast(v_detalle->>'IDTipoPasajero' as int));
			v_cantidad_total = cast(v_detalle->>'Cantidad' as int) + v_cantidad_total;
			v_total = v_total + v_precio * cast(v_detalle->>'Cantidad' as int);
		end LOOP;
	else
		return '{ 
		"mensaje":"NO TIENE DETALLE LA RESERVA"
		}';
	end if;
-- return (select reservados from vuelo where id =  cast(json_entrada->>'IDVuelo' as int));
	--Validacion Capacidad disponible vuelo
	if v_cantidad_total <=  (select capacidad-reservados from vuelo where id =  cast(json_entrada->>'IDVuelo' as int)) then 

		--Insertar cabecera de la reservacion
		INSERT INTO reserva  ( 
		  id_vuelo ,
		  cliente , 
		  fecha_hora ,
		  estatus,
		  total
		) VALUES (
			cast(json_entrada->>'IDVuelo' as int),
			cast(json_entrada->>'Cliente' as varchar),
			 now(),
			0, 
			v_total
		);
		--Se obtiene el id de la Reserva
		v_reserva_id_seq = (SELECT currval('reserva_id_seq')); 

		
		--se recorre el detalle de la reserva
		if (select json_array_length( json_entrada->'Detalle')) > 0 then 
			FOR v_detalle IN SELECT * FROM json_array_elements( json_entrada->'Detalle')  LOOP
				
				--se optiene el precio real de la reserva
				v_precio = (select precio from vuelo_precio where id_vuelo = cast(json_entrada->>'IDVuelo' as int) and id_tipo_pasajero = cast(v_detalle->>'IDTipoPasajero' as int));
				--se tatliza
				
				--se inserta el detalle de la reserva
				INSERT INTO public.reserva_detalle(
				    id_reserva, id_tipo_pasajero, precio, cantidad, total)
				VALUES (v_reserva_id_seq, cast(v_detalle->>'IDTipoPasajero' as int), v_precio , cast(v_detalle->>'Cantidad' as int), v_precio * cast(v_detalle->>'Cantidad' as int));

			END LOOP;
		end if;
		 
		--modificar los reservados del vuelo
		update vuelo set reservados = reservados + v_cantidad_total where id = cast(json_entrada->>'IDVuelo' as int) ;
	        --se retorna el resultado 
		return (
		select row_to_json(t)from (
			select 
			'RESERVA GUARDADA EXITOSAMENTE' mensaje,
			coalesce(
			(
				select row_to_json(t) from (
					select *,
						coalesce((
						select array_to_json(array_agg(row_to_json(t)))from (

							select * from reserva_detalle rd
							where id_reserva = r.id
							
						)t),'[]') datos

					 from reserva r
					where id = v_reserva_id_seq
				)t
			),'{}') datos
		)t
	);
		
	else

		return '{ 
		"mensaje":"NO HAY ASIENTOS DISPONIBLES"
		}';	
	end if;

	 
	
else
	return '{ 
		"mensaje":"NO EXISTE EL VUELO"
		}';	
end if;

END;
$$;


ALTER FUNCTION public.nueva_reserva(json_entrada json) OWNER TO postgres;

--
-- TOC entry 206 (class 1255 OID 1176859)
-- Name: obtener_reserva(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION obtener_reserva(v_id_reserva integer) RETURNS json
    LANGUAGE plpgsql
    AS $$ 
declare 
	v_reserva_id_seq int;
	v_detalle json;
	v_total numeric(18,2);
	v_precio numeric(18,2);
	v_cantidad_total int;
BEGIN
--Validadcion si existe el vuelo
 if exists ( select * from reserva where id = v_id_reserva) then 
	return  (
		select row_to_json(t) from (
			select r.*,v.fecha fecha_salida ,v.hora_salida,v.hora_llegada,v.numero_vuelo ,a1.nombre aeropuerto_salida,a2.nombre aeropuerto_llegada, a.nombre aerolinea,
				coalesce((
				select array_to_json(array_agg(row_to_json(t)))from (

					select rd.*,tp.descripcion tipo_pasajero from reserva_detalle rd
					inner join tipo_pasajero tp on tp.id = rd.id_tipo_pasajero
					where id_reserva = r.id
					
				)t),'[]') Detalles

			 from reserva r
			 inner join vuelo v on v.id = r.id_vuelo
			 inner join aeropuerto a1 on a1.id = v.id_aeropuerto_salida
			 inner join aeropuerto a2 on a2.id = v.id_aeropuerto_llegada
			 inner join aerolinea a on a.id = v.id_areolinea
			where r.id = v_id_reserva
		)t
	);
else
	return '{ 
		"mensaje":"LA RESERVA NO EXISTE"
		}';	
end if;

END;
$$;


ALTER FUNCTION public.obtener_reserva(v_id_reserva integer) OWNER TO postgres;

--
-- TOC entry 210 (class 1255 OID 1176870)
-- Name: obtener_vuelo(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION obtener_vuelo(v_id_vuelo integer) RETURNS json
    LANGUAGE plpgsql
    AS $$  
BEGIN
--Validadcion si existe el vuelo
 if exists ( select * from vuelo where id = v_id_vuelo) then 
	return  (
		select row_to_json(t) from (
			select v.id, v.fecha fecha_salida ,v.hora_salida,v.hora_llegada,v.numero_vuelo ,a1.nombre aeropuerto_salida,a2.nombre aeropuerto_llegada, a.nombre aerolinea,
				coalesce((
				select array_to_json(array_agg(row_to_json(t)))from (

					select rd.*,tp.descripcion tipo_pasajero from vuelo_precio rd
					inner join tipo_pasajero tp on tp.id = rd.id_tipo_pasajero
					where id_vuelo = v.id
					
				)t),'[]') precios
 
			 from  vuelo v   
			 inner join aeropuerto a1 on a1.id = v.id_aeropuerto_salida
			 inner join aeropuerto a2 on a2.id = v.id_aeropuerto_llegada
			 inner join aerolinea a on a.id = v.id_areolinea
			where v.id = v_id_vuelo
		)t
	);
else
	return '{ 
		"mensaje":"EL VUELO NO EXISTE"
		}';	
end if;

END;
$$;


ALTER FUNCTION public.obtener_vuelo(v_id_vuelo integer) OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 184 (class 1259 OID 1176762)
-- Name: aerolinea; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE aerolinea (
    id integer NOT NULL,
    nombre character varying(50)
);


ALTER TABLE aerolinea OWNER TO postgres;

--
-- TOC entry 183 (class 1259 OID 1176760)
-- Name: aerolinea_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE aerolinea_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE aerolinea_id_seq OWNER TO postgres;

--
-- TOC entry 2183 (class 0 OID 0)
-- Dependencies: 183
-- Name: aerolinea_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE aerolinea_id_seq OWNED BY aerolinea.id;


--
-- TOC entry 182 (class 1259 OID 1176754)
-- Name: aeropuerto; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE aeropuerto (
    id integer NOT NULL,
    nombre character varying(100)
);


ALTER TABLE aeropuerto OWNER TO postgres;

--
-- TOC entry 181 (class 1259 OID 1176752)
-- Name: aeropuerto_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE aeropuerto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE aeropuerto_id_seq OWNER TO postgres;

--
-- TOC entry 2184 (class 0 OID 0)
-- Dependencies: 181
-- Name: aeropuerto_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE aeropuerto_id_seq OWNED BY aeropuerto.id;


--
-- TOC entry 191 (class 1259 OID 1176816)
-- Name: reserva; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE reserva (
    id integer NOT NULL,
    id_vuelo integer,
    cliente character varying(50),
    total numeric(18,2),
    fecha_hora timestamp without time zone NOT NULL,
    estatus integer
);


ALTER TABLE reserva OWNER TO postgres;

--
-- TOC entry 193 (class 1259 OID 1176829)
-- Name: reserva_detalle; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE reserva_detalle (
    id integer NOT NULL,
    id_reserva integer,
    id_tipo_pasajero integer,
    precio numeric(18,2) NOT NULL,
    cantidad integer NOT NULL,
    total numeric(18,2) NOT NULL
);


ALTER TABLE reserva_detalle OWNER TO postgres;

--
-- TOC entry 192 (class 1259 OID 1176827)
-- Name: reserva_detalle_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE reserva_detalle_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE reserva_detalle_id_seq OWNER TO postgres;

--
-- TOC entry 2185 (class 0 OID 0)
-- Dependencies: 192
-- Name: reserva_detalle_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE reserva_detalle_id_seq OWNED BY reserva_detalle.id;


--
-- TOC entry 190 (class 1259 OID 1176814)
-- Name: reserva_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE reserva_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE reserva_id_seq OWNER TO postgres;

--
-- TOC entry 2186 (class 0 OID 0)
-- Dependencies: 190
-- Name: reserva_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE reserva_id_seq OWNED BY reserva.id;


--
-- TOC entry 186 (class 1259 OID 1176770)
-- Name: tipo_pasajero; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE tipo_pasajero (
    id integer NOT NULL,
    descripcion character varying(50)
);


ALTER TABLE tipo_pasajero OWNER TO postgres;

--
-- TOC entry 185 (class 1259 OID 1176768)
-- Name: tipo_pasajero_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE tipo_pasajero_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE tipo_pasajero_id_seq OWNER TO postgres;

--
-- TOC entry 2187 (class 0 OID 0)
-- Dependencies: 185
-- Name: tipo_pasajero_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE tipo_pasajero_id_seq OWNED BY tipo_pasajero.id;


--
-- TOC entry 188 (class 1259 OID 1176778)
-- Name: vuelo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE vuelo (
    id integer NOT NULL,
    id_aeropuerto_salida integer NOT NULL,
    id_aeropuerto_llegada integer NOT NULL,
    id_areolinea integer,
    fecha date,
    hora_salida time without time zone NOT NULL,
    hora_llegada time without time zone NOT NULL,
    numero_vuelo character varying(10),
    capacidad integer,
    reservados integer
);


ALTER TABLE vuelo OWNER TO postgres;

--
-- TOC entry 187 (class 1259 OID 1176776)
-- Name: vuelo_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE vuelo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE vuelo_id_seq OWNER TO postgres;

--
-- TOC entry 2188 (class 0 OID 0)
-- Dependencies: 187
-- Name: vuelo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE vuelo_id_seq OWNED BY vuelo.id;


--
-- TOC entry 189 (class 1259 OID 1176799)
-- Name: vuelo_precio; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE vuelo_precio (
    id_vuelo integer NOT NULL,
    id_tipo_pasajero integer NOT NULL,
    precio numeric(18,2) NOT NULL
);


ALTER TABLE vuelo_precio OWNER TO postgres;

--
-- TOC entry 2021 (class 2604 OID 1176765)
-- Name: aerolinea id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY aerolinea ALTER COLUMN id SET DEFAULT nextval('aerolinea_id_seq'::regclass);


--
-- TOC entry 2020 (class 2604 OID 1176757)
-- Name: aeropuerto id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY aeropuerto ALTER COLUMN id SET DEFAULT nextval('aeropuerto_id_seq'::regclass);


--
-- TOC entry 2024 (class 2604 OID 1176819)
-- Name: reserva id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY reserva ALTER COLUMN id SET DEFAULT nextval('reserva_id_seq'::regclass);


--
-- TOC entry 2025 (class 2604 OID 1176832)
-- Name: reserva_detalle id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY reserva_detalle ALTER COLUMN id SET DEFAULT nextval('reserva_detalle_id_seq'::regclass);


--
-- TOC entry 2022 (class 2604 OID 1176773)
-- Name: tipo_pasajero id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tipo_pasajero ALTER COLUMN id SET DEFAULT nextval('tipo_pasajero_id_seq'::regclass);


--
-- TOC entry 2023 (class 2604 OID 1176781)
-- Name: vuelo id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY vuelo ALTER COLUMN id SET DEFAULT nextval('vuelo_id_seq'::regclass);


--
-- TOC entry 2165 (class 0 OID 1176762)
-- Dependencies: 184
-- Data for Name: aerolinea; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO aerolinea (id, nombre) VALUES (1, 'Avianca (Colombia) ');
INSERT INTO aerolinea (id, nombre) VALUES (2, 'SATENA (Colombia) ');
INSERT INTO aerolinea (id, nombre) VALUES (3, 'Wingo (Colombia) ');
INSERT INTO aerolinea (id, nombre) VALUES (4, 'LATAM Colombia (Colombia) ');
INSERT INTO aerolinea (id, nombre) VALUES (5, 'EasyFly (Colombia) ');
INSERT INTO aerolinea (id, nombre) VALUES (6, 'Regional Express Americas SAS (Colombia)');


--
-- TOC entry 2163 (class 0 OID 1176754)
-- Dependencies: 182
-- Data for Name: aeropuerto; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO aeropuerto (id, nombre) VALUES (5, 'Aeropuerto Internacional El Edén (1)');
INSERT INTO aeropuerto (id, nombre) VALUES (6, 'Aeropuerto Internacional Ernesto Cortissoz (3)');
INSERT INTO aeropuerto (id, nombre) VALUES (7, 'Aeropuerto Internacional El Dorado (48)');
INSERT INTO aeropuerto (id, nombre) VALUES (8, 'Aeropuerto Internacional Palonegro (2)');
INSERT INTO aeropuerto (id, nombre) VALUES (9, 'Aeropuerto Internacional Alfonso Bonilla Aragón (9)');
INSERT INTO aeropuerto (id, nombre) VALUES (10, 'Aeropuerto Internacional Camilo Daza (0, 3 en planes)');
INSERT INTO aeropuerto (id, nombre) VALUES (11, 'Aeropuerto Internacional Rafael Núñez (14)');
INSERT INTO aeropuerto (id, nombre) VALUES (12, 'Aeropuerto Internacional Alfredo Vásquez Cobo (1)');
INSERT INTO aeropuerto (id, nombre) VALUES (13, 'Aeropuerto Internacional José María Córdova (15)');
INSERT INTO aeropuerto (id, nombre) VALUES (14, 'Aeropuerto Internacional Matecaña (3)');
INSERT INTO aeropuerto (id, nombre) VALUES (15, 'Aeropuerto Internacional Gustavo Rojas Pinilla (2)');
INSERT INTO aeropuerto (id, nombre) VALUES (16, 'Aeropuerto Internacional Simón Bolívar (1)');
INSERT INTO aeropuerto (id, nombre) VALUES (17, 'Aeropuerto Internacional Los Garzones (1)');
INSERT INTO aeropuerto (id, nombre) VALUES (18, 'Aeropuerto Internacional Almirante Padilla (1)');


--
-- TOC entry 2172 (class 0 OID 1176816)
-- Dependencies: 191
-- Data for Name: reserva; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO reserva (id, id_vuelo, cliente, total, fecha_hora, estatus) VALUES (1, 3, 'ANGEL LABORI', 34.00, '2021-06-15 22:48:28.621481', 0);
INSERT INTO reserva (id, id_vuelo, cliente, total, fecha_hora, estatus) VALUES (2, 3, 'ANGEL LABORI', 34.00, '2021-06-15 22:48:55.390536', 0);
INSERT INTO reserva (id, id_vuelo, cliente, total, fecha_hora, estatus) VALUES (4, 3, 'ANGEL LABORI', 34.00, '2021-06-15 22:51:39.870429', 0);


--
-- TOC entry 2174 (class 0 OID 1176829)
-- Dependencies: 193
-- Data for Name: reserva_detalle; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO reserva_detalle (id, id_reserva, id_tipo_pasajero, precio, cantidad, total) VALUES (1, 1, 1, 10.00, 2, 20.00);
INSERT INTO reserva_detalle (id, id_reserva, id_tipo_pasajero, precio, cantidad, total) VALUES (2, 1, 2, 7.00, 2, 14.00);
INSERT INTO reserva_detalle (id, id_reserva, id_tipo_pasajero, precio, cantidad, total) VALUES (3, 2, 1, 10.00, 2, 20.00);
INSERT INTO reserva_detalle (id, id_reserva, id_tipo_pasajero, precio, cantidad, total) VALUES (4, 2, 2, 7.00, 2, 14.00);
INSERT INTO reserva_detalle (id, id_reserva, id_tipo_pasajero, precio, cantidad, total) VALUES (7, 4, 1, 10.00, 2, 20.00);
INSERT INTO reserva_detalle (id, id_reserva, id_tipo_pasajero, precio, cantidad, total) VALUES (8, 4, 2, 7.00, 2, 14.00);


--
-- TOC entry 2167 (class 0 OID 1176770)
-- Dependencies: 186
-- Data for Name: tipo_pasajero; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO tipo_pasajero (id, descripcion) VALUES (1, 'Adultos');
INSERT INTO tipo_pasajero (id, descripcion) VALUES (2, 'Niños');


--
-- TOC entry 2169 (class 0 OID 1176778)
-- Dependencies: 188
-- Data for Name: vuelo; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO vuelo (id, id_aeropuerto_salida, id_aeropuerto_llegada, id_areolinea, fecha, hora_salida, hora_llegada, numero_vuelo, capacidad, reservados) VALUES (3, 5, 6, 1, '2021-06-15', '05:06:00', '05:50:00', 'A014522', 100, 4);


--
-- TOC entry 2170 (class 0 OID 1176799)
-- Dependencies: 189
-- Data for Name: vuelo_precio; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO vuelo_precio (id_vuelo, id_tipo_pasajero, precio) VALUES (3, 2, 7.00);
INSERT INTO vuelo_precio (id_vuelo, id_tipo_pasajero, precio) VALUES (3, 1, 15.00);


--
-- TOC entry 2189 (class 0 OID 0)
-- Dependencies: 183
-- Name: aerolinea_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('aerolinea_id_seq', 6, true);


--
-- TOC entry 2190 (class 0 OID 0)
-- Dependencies: 181
-- Name: aeropuerto_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('aeropuerto_id_seq', 18, true);


--
-- TOC entry 2191 (class 0 OID 0)
-- Dependencies: 192
-- Name: reserva_detalle_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('reserva_detalle_id_seq', 8, true);


--
-- TOC entry 2192 (class 0 OID 0)
-- Dependencies: 190
-- Name: reserva_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('reserva_id_seq', 4, true);


--
-- TOC entry 2193 (class 0 OID 0)
-- Dependencies: 185
-- Name: tipo_pasajero_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('tipo_pasajero_id_seq', 2, true);


--
-- TOC entry 2194 (class 0 OID 0)
-- Dependencies: 187
-- Name: vuelo_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('vuelo_id_seq', 3, true);


--
-- TOC entry 2029 (class 2606 OID 1176767)
-- Name: aerolinea aerolinea_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY aerolinea
    ADD CONSTRAINT aerolinea_pkey PRIMARY KEY (id);


--
-- TOC entry 2027 (class 2606 OID 1176759)
-- Name: aeropuerto aeropuerto_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY aeropuerto
    ADD CONSTRAINT aeropuerto_pkey PRIMARY KEY (id);


--
-- TOC entry 2039 (class 2606 OID 1176834)
-- Name: reserva_detalle reserva_detalle_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY reserva_detalle
    ADD CONSTRAINT reserva_detalle_pkey PRIMARY KEY (id);


--
-- TOC entry 2037 (class 2606 OID 1176821)
-- Name: reserva reserva_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY reserva
    ADD CONSTRAINT reserva_pkey PRIMARY KEY (id);


--
-- TOC entry 2031 (class 2606 OID 1176775)
-- Name: tipo_pasajero tipo_pasajero_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tipo_pasajero
    ADD CONSTRAINT tipo_pasajero_pkey PRIMARY KEY (id);


--
-- TOC entry 2033 (class 2606 OID 1176783)
-- Name: vuelo vuelo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY vuelo
    ADD CONSTRAINT vuelo_pkey PRIMARY KEY (id);


--
-- TOC entry 2035 (class 2606 OID 1176803)
-- Name: vuelo_precio vuelo_precio_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY vuelo_precio
    ADD CONSTRAINT vuelo_precio_pkey PRIMARY KEY (id_vuelo, id_tipo_pasajero);


--
-- TOC entry 2047 (class 2606 OID 1176840)
-- Name: reserva_detalle reserva_detalle_id_reserva_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY reserva_detalle
    ADD CONSTRAINT reserva_detalle_id_reserva_fkey FOREIGN KEY (id_reserva) REFERENCES reserva(id);


--
-- TOC entry 2046 (class 2606 OID 1176835)
-- Name: reserva_detalle reserva_detalle_id_tipo_pasajero_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY reserva_detalle
    ADD CONSTRAINT reserva_detalle_id_tipo_pasajero_fkey FOREIGN KEY (id_tipo_pasajero) REFERENCES tipo_pasajero(id);


--
-- TOC entry 2045 (class 2606 OID 1176822)
-- Name: reserva reserva_id_vuelo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY reserva
    ADD CONSTRAINT reserva_id_vuelo_fkey FOREIGN KEY (id_vuelo) REFERENCES vuelo(id);


--
-- TOC entry 2041 (class 2606 OID 1176789)
-- Name: vuelo vuelo_id_aeropuerto_llegada_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY vuelo
    ADD CONSTRAINT vuelo_id_aeropuerto_llegada_fkey FOREIGN KEY (id_aeropuerto_llegada) REFERENCES aeropuerto(id);


--
-- TOC entry 2040 (class 2606 OID 1176784)
-- Name: vuelo vuelo_id_aeropuerto_salida_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY vuelo
    ADD CONSTRAINT vuelo_id_aeropuerto_salida_fkey FOREIGN KEY (id_aeropuerto_salida) REFERENCES aeropuerto(id);


--
-- TOC entry 2042 (class 2606 OID 1176794)
-- Name: vuelo vuelo_id_areolinea_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY vuelo
    ADD CONSTRAINT vuelo_id_areolinea_fkey FOREIGN KEY (id_areolinea) REFERENCES aerolinea(id);


--
-- TOC entry 2044 (class 2606 OID 1176809)
-- Name: vuelo_precio vuelo_precio_id_tipo_pasajero_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY vuelo_precio
    ADD CONSTRAINT vuelo_precio_id_tipo_pasajero_fkey FOREIGN KEY (id_tipo_pasajero) REFERENCES tipo_pasajero(id);


--
-- TOC entry 2043 (class 2606 OID 1176804)
-- Name: vuelo_precio vuelo_precio_id_vuelo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY vuelo_precio
    ADD CONSTRAINT vuelo_precio_id_vuelo_fkey FOREIGN KEY (id_vuelo) REFERENCES vuelo(id);


--
-- TOC entry 2181 (class 0 OID 0)
-- Dependencies: 6
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


-- Completed on 2021-06-16 00:54:28

--
-- PostgreSQL database dump complete
--


