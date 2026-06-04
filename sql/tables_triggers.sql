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
    ncitazioni integer CHECK( ncitazioni >= 0) DEFAULT 0 ,
    npagine integer CHECK( npagine > 0) NOT NULL ,
    CONSTRAINT pubblicazione_pkey PRIMARY KEY (codice)
);

-- Tabella Articoli
CREATE TABLE articoli(
    CodicePubblicazione integer NOT NULL,
    tipo varchar(50) NOT NULL CHECK(tipo IN ('Rivista', 'Conferenza')),
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

--TRIGGER AGGIUNTI PER COMPLETEZZA
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
    END IF;
    
    -- 2. Controllo esclusività degli attributi in base al Tipo di articolo
    IF NEW.Tipo = 'Conferenza' THEN
        IF NEW.LuogoConferenza IS NULL OR NEW.AnnoConferenza IS NULL THEN
            RAISE EXCEPTION 'Per gli articoli di tipo Conferenza è obbligatorio inserire Luogo e Anno Conferenza';
        END IF;
        IF NEW.Nvolume IS NOT NULL THEN 
            RAISE EXCEPTION 'Un articolo di tipo Conferenza non può avere un Numero di Volume';
        END IF;
    END IF;
    IF NEW.Tipo = 'Rivista' THEN
        IF NEW.Nvolume IS NULL THEN 
            RAISE EXCEPTION 'Per gli articoli di tipo Rivista è obbligatorio inserire il Numero del Volume';
        END IF;
        IF NEW.LuogoConferenza IS NOT NULL OR NEW.AnnoConferenza IS NOT NULL THEN
            RAISE EXCEPTION 'Un articolo di tipo Rivista non può avere Luogo o Anno Conferenza';
        END IF;
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