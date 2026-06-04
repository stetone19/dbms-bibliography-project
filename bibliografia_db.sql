-- Tabella Affiliazioni
CREATE TABLE affiliazioni
(
    nome varchar(100) NOT NULL ,
    telefono varchar(100) NOT NULL ,
    indirizzo varchar(100) NOT NULL ,
    tipo varchar(20),
    CONSTRAINT affiliazione_pkey PRIMARY KEY ( nome )
);

-- Tabella Pubblicazioni
CREATE TABLE pubblicazioni
(
    codice SERIAL NOT NULL,
    titolo varchar(200),
    annopubblicazione integer NOT NULL,
    ncitazioni integer CHECK( ncitazioni > 0) DEFAULT 0 ,
    npagine integer CHECK( npagine > 0) NOT NULL ,
    CONSTRAINT pubblicazione_pkey PRIMARY KEY (codice)
);

-- Tabella Articoli
CREATE TABLE articoli(
    CodicePubblicazione integer NOT NULL,
    tipo varchar(50) NOT NULL CHECK(tipo IN ['Rivista', 'Conferenza']),
    nome varchar(255) NOT NULL,
    Npaginainiziale integer,
    Nvolume integer,
    luogoConferenza varchar(100),
    annoConferenza integer,
    CONSTRAINT articolo_pkey PRIMARY KEY (CodicePubblicazione),
    CONSTRAINT articolo_codice_pubblicazione_fkey FOREIGN KEY (CodicePubblicazione)
    REFERENCES public.pubblicazioni(codice) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE CASCADE
);

-- Tabella AutoreAffiliazione
CREATE TABLE autoreaffiliazione
(
    idAutore integer NOT NULL,
    nomeAffiliazione varchar(255) NOT NULL,
    CONSTRAINT auto_aff_pkey PRIMARY KEY (idautore,nomeaffiliazione),
    CONSTRAINT auto_aff_id_autore_fkey FOREIGN KEY (idautore)
    REFERENCES public.autori(id) MATCH SIMPLE
    ON UPDATE CASCADE
    ON DELETE CASCADE,
    CONSTRAINT auto_aff_nome_affiliazione_fkey FOREIGN KEY(nomeaffiliazione)
    REFERENCES public.affiliazioni(nome) MATCH SIMPLE
    ON UPDATE CASCADE
    ON DELETE CASCADE
);

-- Tabella Autori
CREATE TABLE autori
(
    id SERIAL NOT NULL,
    nome varchar(100) NOT NULL,
    cognome varchar(100) NOT NULL,
    email varchar(100) NOT NULL,
    sitoweb varchar(100) NOT NULL,
    CONSTRAINT autore_pkey PRIMARY KEY(id)
);
-- Tabella Citazioni
CREATE TABLE citazioni
(
    pubblicazioneCitante integer NOT NULL ,
    pubblicazioneCitata integer NOT NULL ,
    CONSTRAINT citazione_pkey PRIMARY KEY (pubblicazioneCitante,pubblicazioneCitata),
    CONSTRAINT citazione_codice_pubblicazione_citante_fkey FOREIGN KEY (pubblicazioneCitante)
    REFERENCES public.pubblicazioni(codice) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE CASCADE,
    CONSTRAINT citazione_codice_pubblicazione_citata_fkey FOREIGN KEY (pubblicazioneCitata)
    REFERENCES public.pubblicazioni(codice) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE CASCADE
);
-- Tabella Editori
CREATE TABLE editori
(
    nome varchar(100) NOT NULL,
    indirizzo varchar(255) NOT NULL,
    CONSTRAINT editore_pkey PRIMARY KEY(nome)
);
-- Tabella Libri
CREATE TABLE libri
(
    CodicePubblicazione integer NOT NULL,
    isbn varchar(17) UNIQUE NOT NULL,
    nomeEditore varchar(100) NOT NULL,
    CONSTRAINT libro_pkey PRIMARY KEY (CodicePubblicazione),
    CONSTRAINT libro_codice_pubblicazione_fkey FOREIGN KEY (CodicePubblicazione)
    REFERENCES public.pubblicazioni(codice) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE CASCADE,
    CONSTRAINT libro_nome_editore_fkey FOREIGN KEY (nomeEditore)
    REFERENCES public.editori(nome) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
);
-- Tabella PubblicazioneAutore
CREATE TABLE pubblicazioneautore
(
    CodicePubblicazione integer NOT NULL,
    idAutore integer NOT NULL,
    CONSTRAINT pubb_autore_pkey PRIMARY KEY (CodicePubblicazione,idAutore),
    CONSTRAINT pubb_autore_codice_pubblicazione_fkey FOREIGN KEY (CodicePubblicazione)
    REFERENCES public.pubblicazioni(codice) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE CASCADE,
    CONSTRAINT pubb_autore_id_autore_fkey FOREIGN KEY (idAutore)
    REFERENCES public.autori(id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE CASCADE
);

-- Tabella Tesi
CREATE TABLE tesi
(
    CodicePubblicazione integer NOT NULL ,
    argomento text NOT NULL ,
    nomeAffiliazione varchar (255) NOT NULL ,
    CONSTRAINT tesi_pkey PRIMARY KEY ( CodicePubblicazione ) ,
    CONSTRAINT tesi_codice_pubblicazione_fkey FOREIGN KEY (CodicePubblicazione)
    REFERENCES public.pubblicazioni(codice) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE CASCADE ,
    CONSTRAINT tesi_nome_affiliazione_fkey FOREIGN KEY (nomeAffiliazione)
    REFERENCES public.affiliazioni ( nome ) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
);

-- 1. TRIGGER PER L'INSERIMENTO (Incremento e Controlli)
CREATE OR REPLACE FUNCTION inc_n_citazioni()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
    DECLARE
        v_anno_citante integer;
        v_anno_citata integer;
    BEGIN
        -- Controllo auto-citazione immediato
        IF NEW.pubblicazioneCitante = NEW.pubblicazioneCitata THEN
            RAISE EXCEPTION 'Una pubblicazione non si può citare da sola';
        END IF;

        -- Recupero gli anni di pubblicazione (usando i nomi corretti dello schema)
        SELECT annopubblicazione INTO v_anno_citante 
        FROM public.pubblicazioni 
        WHERE codice = NEW.PubblicazioneCitante;

        SELECT annopubblicazione INTO v_anno_citata 
        FROM public.pubblicazioni 
        WHERE codice = NEW.PubblicazioneCitata;

        -- Controllo temporale
        IF v_anno_citante < v_anno_citata THEN
            RAISE EXCEPTION 'Una pubblicazione può citare solo pubblicazioni contemporanee o più vecchie';
        END IF;
		--Se A cita B, B non può citare A
        IF v_anno_citante = v_anno_citata THEN
			IF EXISTS( SELECT *	FROM CITAZIONI	WHERE pubblicazionecitata = NEW.PubblicazioneCitante AND pubblicazionecitante = NEW.PubblicazioneCitata) THEN
				RAISE EXCEPTION 'Creazione di una citazione ciclica';
			END IF;
		END IF;

		--Aggiornamento
        UPDATE public.pubblicazioni
        SET ncitazioni = ncitazioni + 1
        WHERE codice = NEW.PubblicazioneCitata;

        RETURN NEW;
    END;
$$;

CREATE TRIGGER trg_ins_CIT
BEFORE INSERT ON public.citazioni
FOR EACH ROW EXECUTE FUNCTION inc_n_citazioni();

-- 2. TRIGGER PER LA CANCELLAZIONE (Decremento)
CREATE OR REPLACE FUNCTION dec_n_citazioni()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
    BEGIN
        -- Aggiornamento diretto senza bisogno di SELECT preventiva
        UPDATE public.pubblicazioni
        SET ncitazioni = ncitazioni - 1
        WHERE codice = OLD.PubblicazioneCitata;
        
        RETURN OLD;
    END;
$$;

CREATE TRIGGER trg_rim_CIT
BEFORE DELETE ON public.citazioni
FOR EACH ROW EXECUTE FUNCTION dec_n_citazioni();

-- 3. TRIGGER PER BLOCCARE L'UPDATE
CREATE OR REPLACE FUNCTION updt_citazioni()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
    BEGIN
        RAISE EXCEPTION 'Una citazione non può essere aggiornata. Elimina la vecchia e inseriscine una nuova.';
    END;
$$;

CREATE TRIGGER trg_upd_CIT
BEFORE UPDATE ON public.citazioni
FOR EACH ROW EXECUTE FUNCTION updt_citazioni();

CREATE OR REPLACE FUNCTION check_uni()
    RETURNS TRIGGER
    LANGUAGE plpgsql AS 
    $$
    BEGIN
    IF EXISTS(SELECT CodicePubblicazione FROM ARTICOLI WHERE NEW.CodicePubblicazione = CodicePubblicazione)
    OR EXISTS(SELECT CodicePubblicazione FROM LIBRI WHERE NEW.CodicePubblicazione = CodicePubblicazione) THEN
        RAISE EXCEPTION 'Il codice della pubblicazione è attualmente in uso';
        RETURN NULL;
    END IF;
    
    IF NOT EXISTS(SELECT nome FROM AFFILIAZIONI WHERE NEW.nomeAffiliazione = nome AND tipo = 'Università') THEN
        RAISE EXCEPTION 'Università inserita non corretta o non presente nel db';
    END IF;
    
    IF NEW.nomeAffiliazione NOT IN(SELECT AA.nomeAffiliazione
                                   FROM PUBBLICAZIONEAUTORE PA, AUTOREAFFILIAZIONE AA
                                   WHERE PA.CodicePubblicazione = NEW.CodicePubblicazione AND AA.idAutore = PA.idAutore) THEN
        RAISE EXCEPTION 'Università inserita non è affiliata neanche ad un autore';
    END IF;
        
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_TESI
BEFORE INSERT OR UPDATE ON TESI
FOR EACH ROW EXECUTE FUNCTION check_uni();

--TRIGGER LIBRI
CREATE OR REPLACE FUNCTION check_libro()
    RETURNS TRIGGER
    LANGUAGE plpgsql AS 
    $$
    BEGIN
    -- 1. Controllo vincolo di esclusività della gerarchia
    IF EXISTS(SELECT CodicePubblicazione FROM ARTICOLI WHERE NEW.CodicePubblicazione = CodicePubblicazione)
    OR EXISTS(SELECT CodicePubblicazione FROM TESI WHERE NEW.CodicePubblicazione = CodicePubblicazione) THEN
        RAISE EXCEPTION 'Il codice della pubblicazione è attualmente in uso in un altro tipo (Articolo o Tesi)';
        RETURN NULL;
    END IF;
    
    -- 2. Controllo esistenza dell'editore (NomeEditore)
    IF NOT EXISTS(SELECT Nome FROM EDITORI WHERE NEW.NomeEditore = Nome) THEN
        RAISE EXCEPTION 'L''editore inserito non è presente nel database';
    END IF;
    
    RETURN NEW;
END;
$$;

--TRIGGER ARTICOLO
CREATE OR REPLACE FUNCTION check_articolo()
    RETURNS TRIGGER
    LANGUAGE plpgsql AS 
    $$
    BEGIN
    -- 1. Controllo vincolo di esclusività della gerarchia
    IF EXISTS(SELECT CodicePubblicazione FROM LIBRI WHERE NEW.CodicePubblicazione = CodicePubblicazione)
    OR EXISTS(SELECT CodicePubblicazione FROM TESI WHERE NEW.CodicePubblicazione = CodicePubblicazione) THEN
        RAISE EXCEPTION 'Il codice della pubblicazione è attualmente in uso in un altro tipo (Libro o Tesi)';
        RETURN NULL;
    END IF;
    
    -- 2. Controllo esclusività degli attributi in base al Tipo di articolo
    IF NEW.Tipo = 'Conferenza' THEN
        IF NEW.LuogoConferenza IS NULL OR NEW.AnnoConferenza IS NULL THEN
            RAISE EXCEPTION 'Per gli articoli di tipo Conferenza è obbligatorio inserire Luogo e Anno Conferenza';
        END IF;
        IF NEW.Nvolume IS NOT NULL THEN 
            RAISE EXCEPTION 'Un articolo di tipo Conferenza non può avere un Numero di Volume';
        END IF;
        
    IF NEW.Tipo = 'Rivista' THEN
        IF NEW.Nvolume IS NULL THEN 
            RAISE EXCEPTION 'Per gli articoli di tipo Rivista è obbligatorio inserire il Numero del Volume';
        END IF;
        IF NEW.LuogoConferenza IS NOT NULL OR NEW.AnnoConferenza IS NOT NULL THEN
            RAISE EXCEPTION 'Un articolo di tipo Rivista non può avere Luogo o Anno Conferenza';
        END IF;
        
    ELSE
        RAISE EXCEPTION 'Il tipo di articolo inserito non è valido (Specificare "Conferenza" o "Rivista")';
    END IF;
    
    RETURN NEW;
END;
$$;

--TRIGGER PUBBLICAZIONEAUTORE
CREATE OR REPLACE FUNCTION check_pubblicazione_autore()
    RETURNS TRIGGER
    LANGUAGE plpgsql AS 
    $$
    BEGIN
    -- 1. Controllo esistenza dell'autore
    IF NOT EXISTS(SELECT ID FROM AUTORI WHERE NEW.IDAutore = ID) THEN
        RAISE EXCEPTION 'L''autore con ID % inserito non esiste nel database', NEW.IDAutore;
        RETURN NULL;
    END IF;
    
    -- 2. Controllo esistenza della pubblicazione
    IF NOT EXISTS(SELECT Codice FROM PUBBLICAZIONI WHERE NEW.CodicePubblicazione = Codice) THEN
        RAISE EXCEPTION 'La pubblicazione con Codice % inserita non esiste nel database', NEW.CodicePubblicazione;
        RETURN NULL;
    END IF;
    
    RETURN NEW;
END;
$$;

--TRIGGER AUTOREAFFILIAZIONE
CREATE OR REPLACE FUNCTION check_autore_affiliazione()
    RETURNS TRIGGER
    LANGUAGE plpgsql AS 
    $$
    BEGIN
    -- 1. Controllo esistenza dell'autore
    IF NOT EXISTS(SELECT ID FROM AUTORI WHERE NEW.IDAutore = ID) THEN
        RAISE EXCEPTION 'L''autore con ID % inserito non esiste nel database', NEW.IDAutore;
        RETURN NULL;
    END IF;
    
    -- 2. Controllo esistenza dell''affiliazione
    IF NOT EXISTS(SELECT Nome FROM AFFILIAZIONI WHERE NEW.NomeAffiliazione = Nome) THEN
        RAISE EXCEPTION 'L''affiliazione "%" inserita non esiste nel database', NEW.NomeAffiliazione;
        RETURN NULL;
    END IF;
    
    RETURN NEW;
END;
$$;
-- ATTIVAZIONE DEI TRIGGER MANCANTI
CREATE OR REPLACE TRIGGER trigger_libro
BEFORE INSERT OR UPDATE ON LIBRI
FOR EACH ROW
EXECUTE FUNCTION check_libro();

CREATE OR REPLACE TRIGGER trigger_articolo
BEFORE INSERT OR UPDATE ON ARTICOLI
FOR EACH ROW
EXECUTE FUNCTION check_articolo();

CREATE OR REPLACE TRIGGER trigger_pubb_autore
BEFORE INSERT OR UPDATE ON PUBBLICAZIONEAUTORE
FOR EACH ROW
EXECUTE FUNCTION check_pubblicazione_autore();

CREATE OR REPLACE TRIGGER trigger_aut_aff
BEFORE INSERT ON AUTOREAFFILIAZIONE
FOR EACH ROW
EXECUTE FUNCTION check_autore_affiliazione();

--INSERIMENTI
INSERT INTO AFFILIAZIONI (Nome, Telefono, Indirizzo, Tipo) VALUES
('Universita degli Studi di Udine', '0432-556111', 'Via Palladio 8, Udine', 'Università'),
('Universita degli Studi di Trieste', '040-5587111', 'Piazzale Europa 1, Trieste', 'Università'),
('SISSA', '040-3787111', 'Via Bonomea 265, Trieste', 'Università'),
('Universita degli Studi di Padova', '049-8275111', 'Via 8 Febbraio 2, Padova', 'Università'),
('Universita Ca Foscari Venezia', '041-2345111', 'Dorsoduro 3246, Venezia', 'Università'),
('Area Science Park', '040-3755111', 'Padriciano 99, Trieste', 'Ente di ricerca'),
('OGS', '040-2140111', 'Borgo Grotta Gigante 42/C, Sgonico', 'Ente di ricerca'),
('CRO Aviano', '0434-659111', 'Via Franco Gallini 2, Aviano', 'Ente di ricerca'),
('Università degli Studi di Trento', '0461-281111', 'Via Calepina, 14, Trento', 'Università'),
('Libera Università di Bolzano', '0471-011000', 'Piazza Università, 1, Bolzano', 'Università'),
('Fondazione Bruno Kessler', '0461-314200', 'Via Santa Croce, 77, Trento', 'Ente di ricerca');

-- 2. Inserimento di 7 Editori
INSERT INTO EDITORI (Nome, Indirizzo) VALUES
('Forum Editrice Universitaria Udinese', 'Via Palladio 8, Udine'),
('EUT Edizioni Universita di Trieste', 'Via Edoardo Weiss 21, Trieste'),
('CLEUP', 'Via G. Belzoni 118, Padova'),
('Il Mulino', 'Strada Maggiore 37, Bologna'),
('Springer', 'Via Decembrio 28, Milano'),
('IEEE', '3 Park Avenue, New York'),
('Elsevier', 'Radarweg 29, Amsterdam');

-- 3. Inserimento di 40 Autori (Senza ID manuale)
INSERT INTO AUTORI (Nome, Cognome, Email, SitoWeb) VALUES
('Luigi', 'Pascu', 'l.pascu@uniud.it', 'www.uniud.it/lpascu'),
('Federico', 'Del Pup', 'f.delpup@uniud.it', 'www.uniud.it/fdelPup'),
('Matteo', 'Passador', 'm.passador@uniud.it', 'www.uniud.it/mpassador'),
('Giulia', 'Morandini', 'g.morandini@uniud.it', 'www.uniud.it/gmorandini'),
('Stefano', 'Toneguzzo', 's.toneguzzo@uniud.it', 'www.uniud.it/stoneguzzo'),
('Luca', 'Braidotti', 'l.braidotti@units.it', 'www.units.it/lbraidotti'),
('Elena', 'Vascotto', 'e.vascotto@units.it', 'www.units.it/evascotto'),
('Paolo', 'Zuliani', 'p.zuliani@units.it', 'www.units.it/pzuliani'),
('Francesca', 'Beltrame', 'f.beltrame@units.it', 'www.units.it/fbeltrame'),
('Matteo', 'Trevisan', 'm.trevisan@units.it', 'www.units.it/mtrevisan'),
('Anna', 'Ferrari', 'a.ferrari@sissa.it', 'www.sissa.it/aferrari'),
('Roberto', 'Russo', 'r.russo@sissa.it', 'www.sissa.it/rrusso'),
('Silvia', 'Esposito', 's.esposito@sissa.it', 'www.sissa.it/sesposito'),
('Davide', 'Colombo', 'd.colombo@sissa.it', 'www.sissa.it/dcolombo'),
('Marta', 'Ricci', 'm.ricci@sissa.it', 'www.sissa.it/mricci'),
('Giovanni', 'Sartori', 'g.sartori@unipd.it', 'www.unipd.it/gsartori'),
('Laura', 'Pavan', 'l.pavan@unipd.it', 'www.unipd.it/lpavan'),
('Alessandro', 'Basso', 'a.basso@unipd.it', 'www.unipd.it/abasso'),
('Federica', 'Carraro', 'f.carraro@unipd.it', 'www.unipd.it/fcarraro'),
('Riccardo', 'Zanella', 'r.zanella@unipd.it', 'www.unipd.it/rzanella'),
('Sara', 'Vianello', 's.vianello@unive.it', 'www.unive.it/svianello'),
('Giacomo', 'Scarpa', 'g.scarpa@unive.it', 'www.unive.it/gscarpa'),
('Martina', 'Boscolo', 'm.boscolo@unive.it', 'www.unive.it/mboscolo'),
('Filippo', 'Zennaro', 'f.zennaro@unive.it', 'www.unive.it/fzennaro'),
('Elisa', 'Niero', 'e.niero@unive.it', 'www.unive.it/eniero'),
('Nicola', 'De Luca', 'n.deluca@area.it', 'www.areasciencepark.it/ndeluca'),
('Valeria', 'Costa', 'v.costa@area.it', 'www.areasciencepark.it/vcosta'),
('Simone', 'Giordano', 's.giordano@area.it', 'www.areasciencepark.it/sgiordano'),
('Ilaria', 'Rizzo', 'i.rizzo@area.it', 'www.areasciencepark.it/irizzo'),
('Enrico', 'Lombardi', 'e.lombardi@area.it', 'www.areasciencepark.it/elombardi'),
('Giorgio', 'Borean', 'g.borean@ogs.it', 'www.ogs.it/gborean'),
('Valentina', 'Daneluzzi', 'v.daneluzzi@ogs.it', 'www.ogs.it/vdaneluzzi'),
('Massimo', 'Lazzari', 'm.lazzari@ogs.it', 'www.ogs.it/mlazzari'),
('Alice', 'Sgobaro', 'a.sgobaro@ogs.it', 'www.ogs.it/asgobaro'),
('Daniele', 'Paoletti', 'd.paoletti@ogs.it', 'www.ogs.it/dpaoletti'),
('Umberto', 'Tirelli', 'u.tirelli@cro.it', 'www.cro.it/utirelli'),
('Lucia', 'Carbone', 'l.carbone@cro.it', 'www.cro.it/lcarbone'),
('Pietro', 'Veronesi', 'p.veronesi@cro.it', 'www.cro.it/pveronesi'),
('Tiziana', 'Aviano', 't.aviano@cro.it', 'www.cro.it/taviano'),
('Claudio', 'Franceschi', 'c.franceschi@cro.it', 'www.cro.it/cfranceschi');

INSERT INTO PUBBLICAZIONI (titolo, annopubblicazione, npagine) VALUES
('Geologia del Carso Triestino', 2018, 250),
('Biotecnologie per la viticoltura del Collio', 2020, 180),
('Fisica Quantistica e Buchi Neri', 2021, 15),
('Terapie sperimentali oncologiche al CRO', 2019, 12),
('Sismologia e monitoraggio delle Alpi Giulie', 2022, 25),
('Machine Learning applicato alla Laguna di Venezia', 2021, 10),
('L''economia del Nord-Est post pandemia', 2023, 210),
('Evoluzione della fauna marina nell''Alto Adriatico', 2017, 20),
('Storia della Repubblica di Venezia e i suoi traffici', 2015, 320),
('Ottimizzazione logistica del Porto di Trieste', 2022, 18),
('Algoritmi predittivi per il dissesto idrogeologico', 2020, 14),
('Analisi del genoma dei vitigni autoctoni friulani', 2018, 120),
('Modelli matematici per fluidodinamica navale', 2019, 200),
('Studio sull''inquinamento da microplastiche in Adriatico', 2021, 15),
('Innovazioni nella robotica chirurgica', 2023, 10),
('Nanomateriali per lo stoccaggio energetico', 2016, 18),
('Letteratura friulana del Novecento', 2018, 180),
('La bora: modelli meteorologici di precisione', 2020, 22),
('Nuovi recettori nelle cellule tumorali epatiche', 2021, 14),
('Efficienza energetica nei data center', 2022, 200),
('Tesi in Progetto di Basi di Dati', 2026, 0),
('Tesi: Reti neurali per la sismologia', 2023, 95),
('Tesi sulle correnti del Golfo di Trieste', 2021, 130),
('Tesi in Ingegneria Clinica applicata', 2020, 105),
('Tesi: Il dialetto triestino nell''epoca moderna', 2019, 150),
('Tesi sull''impatto ambientale delle grandi navi', 2021, 140),
('Tesi: Materiali compositi in campo aerospaziale', 2022, 90),
('Tesi in fisica delle particelle', 2023, 115),
('Tesi: La filiera del legno in Carnia', 2018, 120),
('Tesi: Big Data per la sanita pubblica regionale', 2020, 100),
('Articolo: Reti 5G nel contesto urbano', 2021, 8),
('Articolo: Cybersecurity per le PMI venete', 2022, 12),
('Articolo: Impatto del cambiamento climatico sui ghiacciai', 2019, 15),
('Articolo: Marcatori biologici predittivi', 2020, 10),
('Articolo: Modelli di previsione delle maree', 2023, 14),
('Articolo: Agricoltura di precisione in Veneto', 2021, 9),
('Articolo: Restauro architettonico a Venezia', 2018, 11),
('Articolo: Smart cities: il caso Padova', 2020, 16),
('Articolo: Biologia marina del Golfo', 2017, 13),
('Articolo: Supercalcolo per la meteorologia', 2022, 8),
('Articolo: Fisica dello stato solido', 2016, 12),
('Articolo: Evoluzione genetica dei lieviti', 2019, 9),
('Articolo: Elettronica di potenza', 2021, 10),
('Articolo: Internet of Things in ambito biomedicale', 2022, 14),
('Articolo: Economia circolare nel Triveneto', 2020, 15),
('Articolo: Sviluppo di vaccini a mRNA', 2023, 11),
('Articolo: Automazione industriale', 2018, 12),
('Articolo: Diritto commerciale internazionale', 2019, 18),
('Articolo: Astrofisica stellare', 2021, 15),
('Articolo: Bioinformatica applicata', 2022, 10),
('Articolo: Nuovi polimeri biodegradabili', 2020, 9),
('Articolo: Storia dell''arte paleocristiana', 2017, 14),
('Articolo: Trattamento acque reflue industriali', 2021, 11),
('Articolo: Gestione delle foreste dolomitiche', 2019, 13),
('Articolo: Microelettronica quantistica', 2023, 8),
('Articolo: Analisi del rischio sismico', 2016, 16),
('Articolo: Terapia genica oncologica', 2022, 12),
('Articolo: Modelli linguistici italiani', 2023, 14),
('Articolo: Psicologia cognitiva clinica', 2018, 10),
('Articolo: Glottologia friulana', 2019, 15),
('Articolo: Fotovoltaico ad alta efficienza', 2021, 9),
('Articolo: Nanotecnologie mediche', 2020, 11),
('Articolo: Archeologia ad Aquileia', 2017, 18),
('Articolo: Logistica multimodale', 2022, 12),
('Articolo: Ingegneria tissutale', 2021, 10),
('Articolo: Rilevamento satellitare', 2019, 14),
('Articolo: Geopolitica balcanica', 2023, 11),
('Articolo: Neuroscienze computazionali', 2020, 13),
('Articolo: Fluidodinamica computazionale', 2021, 15),
('Articolo: Economia comportamentale', 2022, 10);

-- 6. Inserimento in LIBRI (Mappatura automatica sui codici auto-generati da 1 a 20)
INSERT INTO LIBRI (CodicePubblicazione, ISBN, NomeEditore) VALUES
(1, '978-8815123456', 'Forum Editrice Universitaria Udinese'),
(2, '978-8815123457', 'Forum Editrice Universitaria Udinese'),
(3, '978-8815123458', 'Springer'),
(4, '978-8815123459', 'Elsevier'),
(5, '978-8815123460', 'EUT Edizioni Universita di Trieste'),
(6, '978-8815123461', 'IEEE'),
(7, '978-8815123462', 'Il Mulino'),
(8, '978-8815123463', 'Springer'),
(9, '978-8815123464', 'Il Mulino'),
(10, '978-8815123465', 'CLEUP'),
(11, '978-8815123466', 'Springer'),
(12, '978-8815123467', 'Forum Editrice Universitaria Udinese'),
(13, '978-8815123468', 'EUT Edizioni Universita di Trieste'),
(14, '978-8815123469', 'Elsevier'),
(15, '978-8815123470', 'Springer'),
(16, '978-8815123471', 'IEEE'),
(17, '978-8815123472', 'Forum Editrice Universitaria Udinese'),
(18, '978-8815123473', 'EUT Edizioni Universita di Trieste'),
(19, '978-8815123474', 'Elsevier'),
(20, '978-8815123475', 'IEEE');

INSERT INTO TESI (CodicePubblicazione, argomento, nomeAffiliazione) VALUES
(21, 'Computer Science', 'Universita degli Studi di Udine'),
(22, 'Sismologia', 'Universita degli Studi di Trieste'),
(23, 'Oceanografia', 'Universita Ca Foscari Venezia'),
(24, 'Bioingegneria', 'Universita degli Studi di Padova'),
(25, 'Lettere', 'Universita degli Studi di Trieste'),
(26, 'Scienze Ambientali', 'Universita Ca Foscari Venezia'),
(27, 'Ingegneria dei Materiali', 'Universita degli Studi di Padova'),
(28, 'Fisica', 'SISSA'),
(29, 'Scienze Agrarie', 'Universita degli Studi di Udine'),
(30, 'Data Science', 'Universita degli Studi di Padova');

INSERT INTO ARTICOLI (CodicePubblicazione, nome, Nvolume, luogoConferenza, annoConferenza, Npaginainiziale, tipo) VALUES
-- Sezione Riviste (Volume presente; Luogo e Anno NULL)
(31, 'Journal of Urban Technology', 12, NULL, NULL, 10, 'Rivista'),
(32, 'Cybersecurity Today', 5, NULL, NULL, 45, 'Rivista'),
(33, 'Climate Science Journal', 22, NULL, NULL, 110, 'Rivista'),
(34, 'Biomarkers in Medicine', 8, NULL, NULL, 30, 'Rivista'),
(35, 'Oceanography Review', 15, NULL, NULL, 1, 'Rivista'),
(36, 'Precision Agriculture Journal', 4, NULL, NULL, 80, 'Rivista'),
(37, 'Journal of Architecture', 33, NULL, NULL, 12, 'Rivista'),
(38, 'Smart Cities Review', 9, NULL, NULL, 50, 'Rivista'),
(39, 'Marine Biology Letters', 41, NULL, NULL, 100, 'Rivista'),
(40, 'Meteorology Computing', 2, NULL, NULL, 5, 'Rivista'),
(41, 'Solid State Physics', 55, NULL, NULL, 20, 'Rivista'),
(42, 'Yeast Genetics Journal', 11, NULL, NULL, 67, 'Rivista'),
(43, 'Power Electronics IEEE', 30, NULL, NULL, 88, 'Rivista'),
(44, 'Biomedical IoT Review', 3, NULL, NULL, 14, 'Rivista'),
(45, 'Circular Economy Quarterly', 7, NULL, NULL, 22, 'Rivista'),
(46, 'Vaccine Research Journal', 19, NULL, NULL, 40, 'Rivista'),
(47, 'Industrial Automation Today', 25, NULL, NULL, 55, 'Rivista'),
(48, 'International Trade Law', 14, NULL, NULL, 90, 'Rivista'),
(49, 'Astrophysics Journal', 60, NULL, NULL, 1, 'Rivista'),
(50, 'Applied Bioinformatics', 8, NULL, NULL, 34, 'Rivista'),

-- Sezione Conferenze (Luogo e Anno presenti; Volume NULL)
(51, 'International Conference on Polymers', NULL, 'Milano', 2020, 15, 'Conferenza'),
(52, 'Art History Symposium', NULL, 'Roma', 2017, 100, 'Conferenza'),
(53, 'Water Treatment Expo', NULL, 'Venezia', 2021, 45, 'Conferenza'),
(54, 'Dolomites Forestry Conference', NULL, 'Belluno', 2019, 10, 'Conferenza'),
(55, 'Quantum Electronics Summit', NULL, 'Trieste', 2023, 77, 'Conferenza'),
(56, 'Seismic Risk Workshop', NULL, 'L''Aquila', 2016, 20, 'Conferenza'),
(57, 'Gene Therapy Congress', NULL, 'Napoli', 2022, 5, 'Conferenza'),
(58, 'Italian Linguistics Conference', NULL, 'Firenze', 2023, 80, 'Conferenza'),
(59, 'Cognitive Psychology Meeting', NULL, 'Padova', 2018, 12, 'Conferenza'),
(60, 'Friulian Language Symposium', NULL, 'Udine', 2019, 30, 'Conferenza'),
(61, 'Solar Energy Convention', NULL, 'Catania', 2021, 55, 'Conferenza'),
(62, 'Medical Nanotech Summit', NULL, 'Torino', 2020, 90, 'Conferenza'),
(63, 'Aquileia Archaeology Workshop', NULL, 'Aquileia', 2017, 11, 'Conferenza'),
(64, 'Global Logistics Conference', NULL, 'Genova', 2022, 44, 'Conferenza'),
(65, 'Tissue Engineering Symposium', NULL, 'Bologna', 2021, 60, 'Conferenza'),
(66, 'Satellite Mapping Expo', NULL, 'Roma', 2019, 15, 'Conferenza'),
(67, 'Balkan Geopolitics Summit', NULL, 'Trieste', 2023, 22, 'Conferenza'),
(68, 'Computational Neuroscience Meeting', NULL, 'Rovereto', 2020, 5, 'Conferenza'),
(69, 'Fluid Dynamics Workshop', NULL, 'Milano', 2021, 88, 'Conferenza'),
(70, 'Behavioral Economics Conference', NULL, 'Venezia', 2022, 33, 'Conferenza');

INSERT INTO public.pubblicazioneautore (CodicePubblicazione, idAutore) VALUES
(1, 1),
(2, 1), (2, 2),
(3, 4), (3, 5),
(4, 4), (4, 5),
(5, 6),
(6, 6), (6, 7),
(7, 11),
(8, 11), (8, 12),
(9, 16),
(10, 16), (10, 17),
(11, 21),
(12, 21), (12, 22),
(13, 26),
(14, 26), (14, 27),
(15, 31),
(16, 31), (16, 32),
(17, 36),
(18, 36), (18, 37),
(19, 8), (19, 13),
(20, 16), (20, 21),
(21, 1),
(22, 31),
(23, 31), (23, 32),
(24, 16),
(25, 6),
(26, 21),
(27, 16),
(28, 11),
(29, 2),
(30, 26),
(31, 40), (31, 39),
(32, 40),
(33, 40),
(34, 40),
(35, 1),
(36, 1),
(37, 6),
(38, 6),
(39, 11),
(40, 11),
(41, 16),
(42, 16),
(43, 21),
(44, 21),
(45, 26),
(46, 26),
(47, 31),
(48, 31),
(49, 36),
(50, 36),
(51, 2), (51, 3),
(52, 7), (52, 8),
(53, 12), (53, 13),
(54, 17), (54, 18),
(55, 22), (55, 23),
(56, 27), (56, 28),
(57, 32), (57, 33), (57, 36),
(58, 37), (58, 38),
(59, 4), (59, 5),
(60, 4), (60, 5),
(61, 9), (61, 14),
(62, 19), (62, 24),
(63, 29), (63, 34),
(64, 1), (64, 2),
(65, 6), (65, 7),
(66, 11), (66, 12),
(67, 16), (67, 17),
(68, 21), (68, 22),
(69, 26), (69, 27),
(70, 31), (70, 32);

INSERT INTO pubblicazioneautore (CodicePubblicazione, idAutore) VALUES 
(31, 1),
(32, 2); 

INSERT INTO citazioni (pubblicazioneCitante, pubblicazioneCitata) VALUES
(35, 31),
(40, 31),
(43, 31),
(44, 31),
(46, 31),
(35, 32),
(46, 32),
(55, 32),
(58, 32),
(67, 32);

INSERT INTO citazioni (pubblicazioneCitante, pubblicazioneCitata) VALUES
(32, 38),
(40, 38),
(44, 38),
(64, 38),
(70, 38),
(10, 38),
(35, 38),
(31, 33),
(35, 33),
(36, 33),
(40, 33),
(53, 33),
(61, 33),
(69, 33),
(44, 34),
(46, 34),
(57, 34),
(64, 34),
(15, 34),
(43, 41),
(49, 41),
(61, 41),
(62, 41),
(28, 41),
(58, 41),
(10, 45),
(32, 45),
(64, 45),
(46, 45),
(55, 45),
(67, 45),
(7, 32),
(7, 36),
(2, 42),
(43, 47),
(7, 48),
(26, 53),
(5, 54),
(68, 59),
(11, 66),
(10, 69);

-- Popolamento della tabella autoreaffiliazione per tutti i 40 autori
INSERT INTO public.autoreaffiliazione (idAutore, nomeAffiliazione) VALUES
-- Autori 1-5: Universita degli Studi di Udine (@uniud.it)
(1, 'Universita degli Studi di Udine'),
(2, 'Universita degli Studi di Udine'),
(3, 'Universita degli Studi di Udine'),
(4, 'Universita degli Studi di Udine'),
(5, 'Universita degli Studi di Udine'),

-- Autori 6-10: Universita degli Studi di Trieste (@units.it)
(6, 'Universita degli Studi di Trieste'),
(7, 'Universita degli Studi di Trieste'),
(8, 'Universita degli Studi di Trieste'),
(9, 'Universita degli Studi di Trieste'),
(10, 'Universita degli Studi di Trieste'),

-- Autori 11-15: SISSA (@sissa.it)
(11, 'SISSA'),
(12, 'SISSA'),
(13, 'SISSA'),
(14, 'SISSA'),
(15, 'SISSA'),

-- Autori 16-20: Universita degli Studi di Padova (@unipd.it)
(16, 'Universita degli Studi di Padova'),
(17, 'Universita degli Studi di Padova'),
(18, 'Universita degli Studi di Padova'),
(19, 'Universita degli Studi di Padova'),
(20, 'Universita degli Studi di Padova'),

-- Autori 21-25: Universita Ca Foscari Venezia (@unive.it)
(21, 'Universita Ca Foscari Venezia'),
(22, 'Universita Ca Foscari Venezia'),
(23, 'Universita Ca Foscari Venezia'),
(24, 'Universita Ca Foscari Venezia'),
(25, 'Universita Ca Foscari Venezia'),

-- Autori 26-30: Area Science Park (@area.it)
(26, 'Area Science Park'),
(27, 'Area Science Park'),
(28, 'Area Science Park'),
(29, 'Area Science Park'),
(30, 'Area Science Park'),

-- Autori 31-35: OGS (@ogs.it)
(31, 'OGS'),
(32, 'OGS'),
(33, 'OGS'),
(34, 'OGS'),
(35, 'OGS'),

-- Autori 36-40: CRO Aviano (@cro.it)
(36, 'CRO Aviano'),
(37, 'CRO Aviano'),
(38, 'CRO Aviano'),
(39, 'CRO Aviano'),
(40, 'CRO Aviano');

INSERT INTO public.autoreaffiliazione (idAutore, nomeAffiliazione) VALUES

(1, 'SISSA'),
(1, 'Area Science Park'),

(3, 'Universita degli Studi di Trieste'),
(3, 'OGS'),

(4, 'Universita degli Studi di Padova'),

(5, 'Universita Ca Foscari Venezia'),
(5, 'CRO Aviano'),

-- Altri autori con singola affiliazione
(6, 'SISSA'),
(8, 'Universita degli Studi di Padova'),
(9, 'Area Science Park'),
(10, 'OGS'),
(31,'Università degli Studi di Trento'),
(38, 'Libera Università di Bolzano'),
(26, 'Fondazione Bruno Kessler');

INSERT INTO public.autoreaffiliazione (idAutore, nomeAffiliazione) VALUES 
(31, 'Universita degli Studi di Trieste'), (32, 'Universita Ca Foscari Venezia'), (26, 'Universita degli Studi di Padova');


--QUERY
--OPERAZIONE 1
--SELECT * FROM PUBBLICAZIONI;

--OPERAZIONE 2
--INSERT INTO PUBBLICAZIONI (titolo, annopubblicazione, npagine) VALUES ('P vs NP', 2021, 100);

--OPERAZIONE 3
--INSERT INTO AUTORI (Nome, Cognome, Email, SitoWeb) VALUES ('Pinco', 'Pallo', 'pp@tim.it', 'www.pinco.it');

--OPERAZIONE 4
--UPDATE AFFILIAZIONI SET indirizzo = 'Piazza Europa, Trento' WHERE indirizzo = 'Piazzale Europa, Trento';

--OP5: autore con più pubblicazioni per ogni affiliazione

SELECT a.Nome, a.Cognome, aa.NomeAffiliazione
FROM AUTORI a
JOIN PUBBLICAZIONEAUTORE pa ON a.ID = pa.IDAutore
JOIN AUTOREAFFILIAZIONE aa ON a.ID = aa.IDAutore
GROUP BY a.ID, a.Nome, a.Cognome, aa.NomeAffiliazione
HAVING COUNT(pa.CodicePubblicazione) = (
    SELECT MAX(cnt)
    FROM (
        SELECT COUNT(pa2.CodicePubblicazione) AS cnt
        FROM AUTORI a2
        JOIN PUBBLICAZIONEAUTORE pa2 ON a2.ID = pa2.IDAutore
        JOIN AUTOREAFFILIAZIONE aa2 ON a2.ID = aa2.IDAutore
        WHERE aa2.NomeAffiliazione = aa.NomeAffiliazione
        GROUP BY a2.ID
    )
);

--OP6: Stampare le coppie che hanno sempre pubblicato come co-autori sempre e solo

SELECT pa1.idAutore, pa2.idAutore
FROM pubblicazioneautore pa1
JOIN pubblicazioneautore pa2 
    ON pa1.CodicePubblicazione = pa2.CodicePubblicazione 
    AND pa1.idAutore < pa2.idAutore
GROUP BY pa1.idAutore, pa2.idAutore
HAVING COUNT(DISTINCT pa1.CodicePubblicazione) = (
    SELECT COUNT(*) 
    FROM pubblicazioneautore pa
    WHERE pa.idAutore = pa1.idAutore
)
AND COUNT(DISTINCT pa2.CodicePubblicazione) = (
    SELECT COUNT(*) 
    FROM pubblicazioneautore pa
    WHERE pa.idAutore = pa2.idAutore
);

--OP7: Stampare gli autori che non hanno mai pubblicato con autori al di fuori della stessa affiliazione

SELECT a.id, a.nome, a.cognome
FROM autori a
WHERE NOT EXISTS (
    SELECT 1
    FROM pubblicazioneautore pa1
    JOIN pubblicazioneautore pa2
        ON pa1.CodicePubblicazione = pa2.CodicePubblicazione
       AND pa1.idAutore <> pa2.idAutore
    JOIN autoreaffiliazione aa1
        ON aa1.idAutore = pa1.idAutore
    JOIN autoreaffiliazione aa2
        ON aa2.idAutore = pa2.idAutore
    WHERE pa1.idAutore = a.id
      AND aa1.nomeAffiliazione <> aa2.nomeAffiliazione
);

--OP8:Trovare gli autori che hanno pubblicato solo articoli, che a 2 anni dalla pubblicazione hanno almeno 5 citazioni

SELECT a.ID, a.Nome, a.Cognome
FROM AUTORI a
WHERE EXISTS (
    SELECT 1 FROM PUBBLICAZIONEAUTORE pa WHERE pa.IDAutore = a.ID
)
AND NOT EXISTS (
    SELECT 1
    FROM PUBBLICAZIONEAUTORE pa
    JOIN PUBBLICAZIONI p ON pa.CodicePubblicazione = p.Codice
    WHERE pa.IDAutore = a.ID
      AND (
          SELECT COUNT(*)
          FROM CITAZIONI c
          JOIN PUBBLICAZIONI pc ON c.PubblicazioneCitante = pc.Codice
          WHERE c.PubblicazioneCitata = p.Codice
            AND (pc.AnnoPubblicazione - p.AnnoPubblicazione) <= 2
      ) < 5
);

