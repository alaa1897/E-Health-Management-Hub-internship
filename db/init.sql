--
-- PostgreSQL database dump
--


-- Dumped from database version 16.14 (Postgres.app)
-- Dumped by pg_dump version 16.14 (Postgres.app)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: admins; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.admins (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    phonenum bigint NOT NULL,
    email character varying(255) NOT NULL,
    password character varying(255) DEFAULT 'Admin@123'::character varying NOT NULL,
    age integer NOT NULL,
    gender character(1) NOT NULL,
    dob date,
    address character varying(255) NOT NULL
);


ALTER TABLE public.admins OWNER TO postgres;

--
-- Name: admins_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.admins_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.admins_id_seq OWNER TO postgres;

--
-- Name: admins_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.admins_id_seq OWNED BY public.admins.id;


--
-- Name: ambulances; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ambulances (
    id integer NOT NULL,
    drivername character varying(255) NOT NULL,
    phonenum bigint NOT NULL,
    vehiclenum character varying(50) NOT NULL,
    available boolean DEFAULT true
);


ALTER TABLE public.ambulances OWNER TO postgres;

--
-- Name: ambulances_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ambulances_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ambulances_id_seq OWNER TO postgres;

--
-- Name: ambulances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ambulances_id_seq OWNED BY public.ambulances.id;


--
-- Name: appointments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.appointments (
    id integer NOT NULL,
    patientid integer,
    doctorid integer,
    date date NOT NULL,
    "time" time without time zone NOT NULL,
    problem character varying(255)
);


ALTER TABLE public.appointments OWNER TO postgres;

--
-- Name: appointments_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.appointments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.appointments_id_seq OWNER TO postgres;

--
-- Name: appointments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.appointments_id_seq OWNED BY public.appointments.id;


--
-- Name: doctors; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.doctors (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    phonenum bigint NOT NULL,
    email character varying(255) NOT NULL,
    password character varying(255) DEFAULT 'Doctor@123'::character varying NOT NULL,
    age integer NOT NULL,
    gender character(1) NOT NULL,
    bloodgroup character varying(3) NOT NULL,
    dob date NOT NULL,
    address character varying(255) NOT NULL,
    education character varying(255) NOT NULL,
    department character varying(255) NOT NULL,
    availability time without time zone[] DEFAULT ARRAY['10:00:00'::time without time zone, '10:15:00'::time without time zone, '10:30:00'::time without time zone, '10:45:00'::time without time zone, '11:00:00'::time without time zone, '11:15:00'::time without time zone, '11:30:00'::time without time zone, '11:45:00'::time without time zone, '14:00:00'::time without time zone, '14:15:00'::time without time zone, '14:30:00'::time without time zone, '14:45:00'::time without time zone, '15:00:00'::time without time zone, '15:15:00'::time without time zone, '15:30:00'::time without time zone, '15:45:00'::time without time zone, '16:00:00'::time without time zone] NOT NULL,
    fees integer NOT NULL
);


ALTER TABLE public.doctors OWNER TO postgres;

--
-- Name: doctor_details; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.doctor_details AS
 SELECT id,
    name,
    phonenum,
    email,
    age,
    gender,
    bloodgroup,
    dob,
    address,
    education,
    department,
    availability,
    fees
   FROM public.doctors;


ALTER VIEW public.doctor_details OWNER TO postgres;

--
-- Name: doctors_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.doctors_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.doctors_id_seq OWNER TO postgres;

--
-- Name: doctors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.doctors_id_seq OWNED BY public.doctors.id;


--
-- Name: hospitals; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.hospitals (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    address character varying(255) NOT NULL,
    city character varying(255) NOT NULL,
    phone bigint
);


ALTER TABLE public.hospitals OWNER TO postgres;

--
-- Name: hospitals_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.hospitals_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.hospitals_id_seq OWNER TO postgres;

--
-- Name: hospitals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.hospitals_id_seq OWNED BY public.hospitals.id;


--
-- Name: patients; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.patients (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    phonenum bigint NOT NULL,
    email character varying(255) NOT NULL,
    password character varying(255) NOT NULL,
    age integer NOT NULL,
    gender character(1),
    bloodgroup character varying(3),
    dob date,
    address character varying(255),
    docid integer
);


ALTER TABLE public.patients OWNER TO postgres;

--
-- Name: patient_details; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.patient_details AS
 SELECT p.id,
    p.name,
    p.phonenum,
    p.email,
    p.age,
    p.gender,
    p.bloodgroup,
    p.dob,
    p.address,
    p.docid,
    d.name AS doctor_name,
    d.department
   FROM (public.patients p
     LEFT JOIN public.doctors d ON ((p.docid = d.id)));


ALTER VIEW public.patient_details OWNER TO postgres;

--
-- Name: patients_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.patients_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.patients_id_seq OWNER TO postgres;

--
-- Name: patients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.patients_id_seq OWNED BY public.patients.id;


--
-- Name: admins id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admins ALTER COLUMN id SET DEFAULT nextval('public.admins_id_seq'::regclass);


--
-- Name: ambulances id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ambulances ALTER COLUMN id SET DEFAULT nextval('public.ambulances_id_seq'::regclass);


--
-- Name: appointments id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments ALTER COLUMN id SET DEFAULT nextval('public.appointments_id_seq'::regclass);


--
-- Name: doctors id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.doctors ALTER COLUMN id SET DEFAULT nextval('public.doctors_id_seq'::regclass);


--
-- Name: hospitals id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hospitals ALTER COLUMN id SET DEFAULT nextval('public.hospitals_id_seq'::regclass);


--
-- Name: patients id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patients ALTER COLUMN id SET DEFAULT nextval('public.patients_id_seq'::regclass);


--
-- Name: admins admins_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admins
    ADD CONSTRAINT admins_pkey PRIMARY KEY (id);


--
-- Name: ambulances ambulances_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ambulances
    ADD CONSTRAINT ambulances_pkey PRIMARY KEY (id);


--
-- Name: appointments appointments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_pkey PRIMARY KEY (id);


--
-- Name: doctors doctors_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.doctors
    ADD CONSTRAINT doctors_pkey PRIMARY KEY (id);


--
-- Name: hospitals hospitals_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hospitals
    ADD CONSTRAINT hospitals_pkey PRIMARY KEY (id);


--
-- Name: patients patients_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_pkey PRIMARY KEY (id);


--
-- Name: appointments appointments_doctorid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_doctorid_fkey FOREIGN KEY (doctorid) REFERENCES public.doctors(id);


--
-- Name: appointments appointments_patientid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_patientid_fkey FOREIGN KEY (patientid) REFERENCES public.patients(id);


--
-- Name: patients patients_docid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_docid_fkey FOREIGN KEY (docid) REFERENCES public.doctors(id);


--
-- PostgreSQL database dump complete
--



--
-- Seed data: test admin account
--

INSERT INTO public.admins (id, name, phonenum, email, password, age, gender, dob, address)
VALUES (1, 'Admin User', 21234567, 'admin@clinic.tn', 'Admin@123', 35, 'M', '1990-01-01', 'Tunis, Tunisia')
ON CONFLICT (id) DO NOTHING;

SELECT setval('public.admins_id_seq', (SELECT COALESCE(MAX(id), 1) FROM public.admins));
