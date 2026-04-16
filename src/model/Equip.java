package model;
public class Equip {
    private final String nom;
    private final Jugador jugador;
    private int gols;
    public Equip(String nom, Jugador jugador) {
        this.nom = nom; this.jugador = jugador; this.gols = 0;
    }
    public void afegirGol() { gols++; }
    public String getNom()      { return nom; }
    public Jugador getJugador() { return jugador; }
    public int getGols()        { return gols; }
}
