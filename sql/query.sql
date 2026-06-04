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

