package model;
public class Jugador {
    private final String nom;
    private int energia;
    private final int habilitat;
    private static final int MAX = 100;
    public Jugador(String nom, int habilitat) {
        this.nom = nom;
        this.habilitat = Math.min(10, Math.max(1, habilitat));
        this.energia = MAX;
    }
    public void reduirEnergia(int q)    { energia = Math.max(0, energia - q); }
    public void recuperarEnergia(int q) { energia = Math.min(MAX, energia + q); }
    public double factorEfectivitat()   { return (habilitat/10.0)*0.6 + (energia/100.0)*0.4; }
    public String getNom()    { return nom; }
    public int getEnergia()   { return energia; }
    public int getHabilitat() { return habilitat; }
}
