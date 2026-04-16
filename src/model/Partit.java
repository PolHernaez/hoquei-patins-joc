package model;

import java.util.Random;

public class Partit {

    public enum Resultat { EN_JOC, VICTORIA_LOCAL, VICTORIA_VISITANT, EMPAT }
    public enum TipusEvent { GOL_LOCAL, GOL_VISITANT, TIR_FALLAT, BLOQUEIG, ROBADA, PASSADA, DESCANS, CAP }

    private static final int TORNS_TOTALS      = 20;
    private static final int TORNS_PER_PERIODE = 10;

    private final Equip  local, visitant;
    private final Random rng = new Random();

    private int     torn           = 1;
    private int     periode        = 1;
    private boolean possessioLocal = true;
    private boolean bonusPassada   = false;

    // Últim event per a la UI
    private String     ultimMissatge = "Comença el partit!";
    private TipusEvent ultimEvent    = TipusEvent.CAP;

    public Partit(Equip local, Equip visitant) {
        this.local    = local;
        this.visitant = visitant;
    }

    public void executarAccio(AccioJoc accio) {
        ultimEvent = TipusEvent.CAP;
        if (possessioLocal) {
            processarAtac(accio, local, visitant);
        } else {
            processarDefensa(accio, local, visitant);
        }
        avançarTorn();
    }

    private void processarAtac(AccioJoc accio, Equip atac, Equip def) {
        Jugador ja = atac.getJugador();
        switch (accio) {
            case TIRAR -> {
                ja.reduirEnergia(20);
                double prob = calcProbGol(ja, bonusPassada);
                bonusPassada = false;
                if (rng.nextDouble() < prob) {
                    atac.afegirGol();
                    possessioLocal = !possessioLocal;
                    ultimMissatge = "GOL! " + ja.getNom() + " marca!";
                    ultimEvent    = TipusEvent.GOL_LOCAL;
                } else {
                    if (rng.nextBoolean()) possessioLocal = !possessioLocal;
                    ultimMissatge = "Tir fallat!";
                    ultimEvent    = TipusEvent.TIR_FALLAT;
                }
            }
            case PASSAR -> {
                ja.reduirEnergia(10);
                bonusPassada  = true;
                ultimMissatge = "Passada! Bonus gol al següent torn.";
                ultimEvent    = TipusEvent.PASSADA;
            }
            case DESCANSAR_ATAC -> {
                ja.recuperarEnergia(25);
                bonusPassada  = false;
                ultimMissatge = ja.getNom() + " descansa (+25 energia)";
                ultimEvent    = TipusEvent.DESCANS;
            }
            default -> {}
        }
    }

    private void processarDefensa(AccioJoc accio, Equip def, Equip atac) {
        Jugador jd = def.getJugador();
        Jugador ja = atac.getJugador();
        ja.reduirEnergia(18);
        boolean golIA = rng.nextDouble() < calcProbGol(ja, false);

        switch (accio) {
            case BLOQUEJAR -> {
                jd.reduirEnergia(15);
                boolean bloqueja = rng.nextDouble() < 0.35 + jd.factorEfectivitat() * 0.35;
                if (golIA && !bloqueja) {
                    atac.afegirGol();
                    possessioLocal = !possessioLocal;
                    ultimMissatge  = "GOL rival! El bloqueig ha fallat.";
                    ultimEvent     = TipusEvent.GOL_VISITANT;
                } else {
                    possessioLocal = !possessioLocal;
                    ultimMissatge  = "BLOQUEIG! Pilota recuperada!";
                    ultimEvent     = TipusEvent.BLOQUEIG;
                }
            }
            case PRESSIONAR -> {
                jd.reduirEnergia(20);
                boolean roba = rng.nextDouble() < 0.25 + jd.factorEfectivitat() * 0.30;
                if (roba) {
                    possessioLocal = !possessioLocal;
                    ultimMissatge  = "ROBADA! " + jd.getNom() + " recupera!";
                    ultimEvent     = TipusEvent.ROBADA;
                } else if (golIA) {
                    atac.afegirGol();
                    possessioLocal = !possessioLocal;
                    ultimMissatge  = "GOL rival! La pressió ha deixat espai.";
                    ultimEvent     = TipusEvent.GOL_VISITANT;
                } else {
                    ultimMissatge = "Pressió fallida. El rival manté la pilota.";
                    ultimEvent    = TipusEvent.TIR_FALLAT;
                }
            }
            case DESCANSAR_DEF -> {
                jd.recuperarEnergia(20);
                if (golIA) {
                    atac.afegirGol();
                    possessioLocal = !possessioLocal;
                    ultimMissatge  = "GOL rival! Aprofita el descans.";
                    ultimEvent     = TipusEvent.GOL_VISITANT;
                } else {
                    ultimMissatge = jd.getNom() + " descansa (+20 energia). Rival falla.";
                    ultimEvent    = TipusEvent.DESCANS;
                }
            }
            default -> {}
        }
    }

    private double calcProbGol(Jugador j, boolean bonus) {
        double prob = 0.30 * j.factorEfectivitat() + 0.05;
        if (bonus) prob = Math.min(prob + 0.20, 0.85);
        return Math.min(prob, 0.80);
    }

    private void avançarTorn() {
        torn++;
        if (torn == TORNS_PER_PERIODE + 1) {
            periode = 2;
            local.getJugador().recuperarEnergia(30);
            visitant.getJugador().recuperarEnergia(30);
        }
    }

    public boolean haAcabat() { return torn > TORNS_TOTALS; }

    public Resultat obtenirResultat() {
        if (!haAcabat()) return Resultat.EN_JOC;
        int gl = local.getGols(), gv = visitant.getGols();
        if (gl > gv) return Resultat.VICTORIA_LOCAL;
        if (gv > gl) return Resultat.VICTORIA_VISITANT;
        return Resultat.EMPAT;
    }

    public Equip    getEquipLocal()      { return local; }
    public Equip    getEquipVisitant()   { return visitant; }
    public int      getTorn()            { return torn; }
    public int      getPeriode()         { return periode; }
    public boolean  isPossessioLocal()   { return possessioLocal; }
    public String   getUltimMissatge()   { return ultimMissatge; }
    public TipusEvent getUltimEvent()    { return ultimEvent; }
    public int getTornsDinsPeriode()     { return ((torn - 1) % TORNS_PER_PERIODE) + 1; }
}
