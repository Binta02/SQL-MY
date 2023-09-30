create database BD;

CREATE TABLE Personne (
 id_personne SERIAL
            PRIMARY KEY,
 nom VARCHAR(50),
 prenom VARCHAR(50)
);

CREATE TABLE Enseignant(
 id_personne int
            REFERENCES Personne(id_personne),
 PRIMARY KEY (id_personne)
);

CREATE TABLE Semestre(
 id_semestre SERIAL
        PRIMARY KEY
);
CREATE TABLE Matiere (
 id_matiere int
            PRIMARY KEY,
 type char(5) UNIQUE,
 id_semestre INT
            REFERENCES Semestre(id_semestre),
 nomM VARCHAR (100),
 id_personne INT
            REFERENCES Personne(id_personne)
);

CREATE TABLE Etudiant (
    id_personne SERIAL PRIMARY KEY,
    classe VARCHAR(50)
);
CREATE TABLE Inscription (
    id_inscription serial
        primary key ,
    id_etudiant INT,
    id_semestre INT,
    FOREIGN KEY (id_etudiant) REFERENCES Etudiant(id_personne),
    FOREIGN KEY (id_semestre) REFERENCES Semestre(id_semestre)
);

CREATE TABLE Competence(
 type_comptence varchar
            PRIMARY KEY,
 nomCompetence VARCHAR,
 SAE VARCHAR
);

CREATE TABLE Coef_competence(
 type_comptence varchar
     references Competence(type_comptence),
 type CHAR(5)
            REFERENCES Matiere(type),
 id_semestre INT
            REFERENCES Semestre(id_semestre),
 id_matiere SERIAL
            REFERENCES Matiere(id_matiere),
 coef INT
);

CREATE TABLE Controle(
 id_controle serial
            PRIMARY KEY,
 type CHAR(5)
            REFERENCES Matiere(type),
 id_semestre INT
            REFERENCES Semestre(id_semestre),
 id_matiere SERIAL
            REFERENCES Matiere(id_matiere),
 date_eval VARCHAR,
 nom_Controle VARCHAR
);

CREATE TABLE Note (
    id_controle INT
            REFERENCES Controle(id_controle),
    id_semestre INT
            REFERENCES Semestre(id_semestre),
    id_matiere SERIAL
            REFERENCES Matiere(id_matiere),
    type CHAR(5)
            REFERENCES Matiere(type),
    id_personne int
            REFERENCES Etudiant(id_personne),
 id_inscription int
            REFERENCES Inscription(id_inscription),
 note FLOAT
);

CREATE or replace VIEW ReleveNotesEtudiant AS
SELECT P.id_personne, P.nom, P.prenom, E.classe, M.nomM, N.note, I.id_semestre
FROM Personne P
JOIN Etudiant E ON P.id_personne = E.id_personne
JOIN Inscription I on I.id_etudiant = E.id_personne
JOIN Note N ON N.id_inscription = I.id_inscription
JOIN Matiere M ON N.id_matiere = M.id_matiere
join controle c on c.id_semestre=I.id_semestre
GROUP BY P.id_personne, P.nom, P.prenom, E.classe, M.nomM, N.note, I.id_semestre
order by id_semestre;

SELECT nom, prenom, classe, nomM, note, id_semestre
FROM ReleveNotesEtudiant
where id_personne=1;

SELECT nom, prenom, classe, nomM, note, id_semestre
FROM ReleveNotesEtudiant
WHERE classe='Classe A' and id_semestre=2;

DROP view MoyenneCompetence;
CREATE OR REPLACE VIEW MoyenneCompetence AS
SELECT P.id_personne, P.nom, P.prenom, C.nomCompetence,
       M.id_semestre,
       CAST(COALESCE((SUM(N.note * CC.coef) / SUM(CC.coef)), 0) AS numeric(10,2)) AS moyenne
FROM Personne P
JOIN Etudiant E ON P.id_personne = E.id_personne
JOIN Inscription I ON E.id_personne = I.id_etudiant
JOIN Matiere M ON I.id_semestre = M.id_semestre
JOIN Coef_competence CC ON M.type = CC.type AND M.id_semestre = CC.id_semestre AND M.id_matiere = CC.id_matiere
JOIN Competence C ON CC.type_comptence = C.type_comptence
LEFT JOIN Note N ON I.id_inscription = N.id_inscription AND N.id_matiere = M.id_matiere
GROUP BY P.id_personne, P.nom, P.prenom, C.nomCompetence, M.id_semestre
ORDER BY M.id_semestre;

SELECT *
FROM MoyenneCompetence
where id_personne=1;

CREATE OR REPLACE view ResponsableMatiere AS
    select  P.nom, P.prenom, M.nomM
FROM Personne P
join Matiere M on P.id_personne = M.id_personne
GROUP BY P.nom, P.prenom, M.nomM ;

SELECT *
FROM ResponsableMatiere;
drop view MoyenneParGroupeSemestre;

CREATE OR REPLACE VIEW MoyenneParGroupeSemestre AS
SELECT classe, id_semestre, CAST(AVG(note) AS numeric(10,2)) AS moyenne_classe_semestre
FROM ReleveNotesEtudiant
GROUP BY classe, id_semestre;

select * from MoyenneParGroupeSemestre
where classe='Classe A' and id_semestre=1;


CREATE OR REPLACE FUNCTION MoyenneCompetenceParPersonne(id_personne INT)
RETURNS TABLE (nomCompetence VARCHAR, moyenne NUMERIC(10,2))
AS $$
BEGIN
    RETURN QUERY
    SELECT MC.nomCompetence, MC.moyenne
    FROM MoyenneCompetence MC
    WHERE MC.id_personne = MoyenneCompetenceParPersonne.id_personne;
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM MoyenneCompetenceParPersonne(7);

CREATE OR REPLACE FUNCTION obtenirNoteMaxEtudiant(id_etudiant INT, id_matiere INT)
RETURNS FLOAT
AS $$
DECLARE
    note_max FLOAT;
BEGIN
    SELECT MAX(n.note)
    INTO note_max
    FROM Note n
    JOIN Matiere m ON m.id_matiere = n.id_matiere
    JOIN Etudiant e ON e.id_personne = n.id_personne
    WHERE e.id_personne = id_etudiant
        AND m.id_matiere = n.id_matiere;

    RETURN note_max;
END;
$$ LANGUAGE plpgsql;
select * from obtenirNoteMaxEtudiant(1,4);

--DROP FUNCTION passeanneesuivant(integer,integer);
CREATE OR REPLACE FUNCTION PasseAnneeSuivant(id_personne_param INT, semestre_param INT)
RETURNS TABLE (nomCompetence VARCHAR, moyenne NUMERIC(10,2), passe_annee_suivante TEXT)
AS $$
BEGIN
    RETURN QUERY
    SELECT MC.nomCompetence, MC.moyenne,
           CASE WHEN MC.moyenne >= 10 THEN 'validé' ELSE 'invalide' END AS passe_annee_suivante
    FROM MoyenneCompetence MC
    WHERE MC.id_personne = id_personne_param
      AND MC.id_semestre = semestre_param;
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM PasseAnneeSuivant(5,6);

--DROP FUNCTION obtenirrangcompetence(integer);
CREATE OR REPLACE FUNCTION ObtenirRangCompetence(id_personne_param INT, semestre_param INT)
RETURNS TABLE (id_personne INT, nom varchar, prenom varchar, nomCompetence VARCHAR, moyenne NUMERIC, rang BIGINT)
AS $$
BEGIN
    RETURN QUERY
    SELECT P.id_personne, P.nom, P.prenom, MC.nomCompetence, MC.moyenne, RANK() OVER (ORDER BY MC.moyenne DESC) AS rang
    FROM (
        SELECT DISTINCT ON (MC.nomCompetence) MC.id_personne, MC.nomCompetence, MC.moyenne
        FROM MoyenneCompetence MC
        WHERE MC.id_personne = id_personne_param AND MC.id_semestre = semestre_param
        ORDER BY MC.nomCompetence, MC.moyenne DESC
    ) AS MC
    JOIN Personne P ON MC.id_personne = P.id_personne
    WHERE MC.id_personne = id_personne_param;
END;
$$ LANGUAGE plpgsql;
SELECT *
FROM ObtenirRangCompetence(1,2);


INSERT INTO Note (id_semestre, id_matiere, type, note)
SELECT M.id_semestre, M.id_matiere, M.type, 17
FROM Matiere M
JOIN Enseignant E ON M.id_personne = E.id_personne AND M.id_personne =4
JOIN Controle C ON M.id_matiere = C.id_matiere
WHERE M.type = 'R1.01' AND M.id_semestre = 1;

SELECT id_semestre, id_matiere, type, note
FROM Note
WHERE id_semestre = 1
    AND id_matiere = 1
    AND type = 'R1.01';

CREATE FUNCTION InsertNote(
    in EnseignantID int,
    in MatiereID int,
    in Note decimal(4,2)
) RETURNS void AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM Matiere m
        WHERE m.MatiereID = MatiereID
        AND m.EnseignantID = EnseignantID
    ) THEN
        INSERT INTO Note (MatiereID, Note)
        VALUES (MatiereID, Note);
    ELSE
        RAISE EXCEPTION 'Vous n''êtes pas autorisé à insérer une note dans cette matière.';
    END IF;
END;
$$ LANGUAGE plpgsql;

select *from InsertNote(2,2,17)


CREATE OR REPLACE FUNCTION inserer_note_enseignant(p_id_personne INT, p_type VARCHAR, p_semestre INT) RETURNS VOID AS $$
DECLARE
    row_count INT;
BEGIN
    INSERT INTO Note (id_semestre, id_matiere, type, note)
    SELECT M.id_semestre, M.id_matiere, M.type, 17
    FROM Matiere M
    JOIN Enseignant E ON M.id_personne = E.id_personne AND E.id_personne = p_id_personne
    JOIN Controle C ON M.id_matiere = C.id_matiere
    WHERE M.type = p_type AND M.id_semestre = p_semestre;

    GET DIAGNOSTICS row_count = ROW_COUNT;
    IF row_count > 0 THEN
       RAISE NOTICE 'Insertion réussie.';
     ELSE
         RAISE NOTICE 'Aucune insertion effectuée.';
     END IF;
END;
$$ LANGUAGE plpgsql;

SELECT inserer_note_enseignant(2, 'R1.01', 1);


/* Un étudiant peut accéder à la note moyenne, la note la plus petite et la note la plus grande d’un contrôle donné :*/

SELECT AVG(note) AS moyenne, MIN(note) AS minimum, MAX(note) AS maximum
FROM Note
WHERE id_controle = 2;

/* Un enseignant ne peut consulter que les notes de sa propre matière :*/

SELECT m.nomM, c.nom_Controle, n.note, P.nom, P.prenom
FROM Matiere m
JOIN Enseignant e ON m.id_personne = e.id_personne
JOIN Note n ON m.type = n.type AND m.id_semestre = n.id_semestre AND m.id_matiere = n.id_matiere
JOIN Controle c ON n.id_controle = c.id_controle
JOIN personne P ON n.id_personne = P.id_personne
WHERE m.type = 'R1.06' AND m.id_semestre = 1 AND e.id_personne = 4
ORDER BY c.nom_Controle;
--ALTER TABLE note DROP CONSTRAINT unique_note_per_matiere_etudiant; -- efface la restriction

/* Restriction pour empêcher l'insertion de doublons de notes pour une même matière et un même étudiant  */
ALTER TABLE Note
ADD CONSTRAINT unique_note_per_matiere_etudiant
UNIQUE (id_matiere, id_personne);

-- essae d'insert une valeur existante pour voir l'erreur
INSERT INTO Note (id_matiere, id_personne, note)
VALUES (1, 1, 15);

/* a faire si on veut voir que la restriction marche ou pas*/
DELETE FROM Note
WHERE id_matiere = 1 AND id_personne = 1 AND note = 15;
select * from personne;

CREATE USER pablo WITH PASSWORD 'mot_de_passe';

-- Attribution des privilèges
GRANT INSERT, SELECT, UPDATE, DELETE ON note TO pablo;

SELECT grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_name = 'note' AND grantee = 'pablo';