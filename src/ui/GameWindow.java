package ui;

import logic.IAController;
import model.Equip;
import model.Jugador;
import model.Partit;

import javax.swing.*;
import java.awt.*;

public class GameWindow extends JFrame {

    public GameWindow() {
        Jugador pol = new Jugador("Pol Hernáez", 8);
        Jugador bot = new Jugador("Bot FC", 7);

        Equip local    = new Equip("Arenys HC", pol);
        Equip visitant = new Equip("Rivals FC", bot);

        Partit       partit = new Partit(local, visitant);
        IAController ia     = new IAController();
        GamePanel    panel  = new GamePanel(partit, ia);

        setTitle("Hoquei Patins · Pol Hernáez (DAM1)");
        setDefaultCloseOperation(EXIT_ON_CLOSE);
        setResizable(false);
        getContentPane().setBackground(new Color(12, 18, 30));
        add(panel);
        pack();
        setLocationRelativeTo(null);
    }

    public static void iniciar() {
        SwingUtilities.invokeLater(() -> new GameWindow().setVisible(true));
    }

    public static void main(String[] args) {
        // Look and feel del sistema per millor rendering
        try { UIManager.setLookAndFeel(UIManager.getCrossPlatformLookAndFeelClassName()); }
        catch (Exception ignored) {}
        iniciar();
    }
}
