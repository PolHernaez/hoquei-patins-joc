package ui;

import logic.IAController;
import model.AccioJoc;
import model.Equip;
import model.Jugador;
import model.Partit;
import model.Partit.TipusEvent;

import javax.swing.*;
import javax.swing.border.EmptyBorder;
import java.awt.*;

public class GamePanel extends JPanel {

    // Colors generals
    private static final Color BG        = new Color(12, 18, 30);
    private static final Color SCORE_BG  = new Color(20, 28, 45);
    private static final Color LOCAL_C   = new Color(210, 30, 30);
    private static final Color VISIT_C   = new Color(20, 70, 200);
    private static final Color BTN_PASS  = new Color(160, 120, 10);
    private static final Color BTN_REST  = new Color(30, 110, 50);
    private static final Color TEXT_MAIN = new Color(230, 235, 245);
    private static final Color TEXT_DIM  = new Color(130, 140, 160);

    private final Partit       partit;
    private final IAController ia;
    private final GameCanvas   canvas;

    // Components UI
    private JLabel     lblScoreLocal, lblScoreVisit;
    private JLabel     lblNomLocal, lblNomVisit;
    private JLabel     lblInfo;
    private JLabel     lblMissatge;
    private JProgressBar barLocal, barVisit;
    private JPanel     panellBotons;
    private boolean    blocatBotons = false;

    public GamePanel(Partit partit, IAController ia) {
        this.partit = partit;
        this.ia     = ia;
        this.canvas = new GameCanvas(partit);

        setLayout(new BorderLayout(0, 0));
        setBackground(BG);

        add(crearScoreboard(),  BorderLayout.NORTH);
        add(canvas,             BorderLayout.CENTER);
        add(crearPanellInferior(), BorderLayout.SOUTH);

        actualitzarUI();
    }

    // ═══════════════════════════════════════
    //  SCOREBOARD
    // ═══════════════════════════════════════

    private JPanel crearScoreboard() {
        JPanel p = new JPanel(new BorderLayout()) {
            @Override
            protected void paintComponent(Graphics g) {
                super.paintComponent(g);
                Graphics2D g2 = (Graphics2D) g;
                g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
                // Fons scoreboard amb degradat
                GradientPaint gp = new GradientPaint(0, 0, new Color(25, 35, 58), 0, getHeight(), SCORE_BG);
                g2.setPaint(gp);
                g2.fillRect(0, 0, getWidth(), getHeight());
                // Línia inferior
                g2.setColor(new Color(50, 70, 110));
                g2.setStroke(new BasicStroke(1));
                g2.drawLine(0, getHeight() - 1, getWidth(), getHeight() - 1);
            }
        };
        p.setOpaque(false);
        p.setPreferredSize(new Dimension(0, 90));

        // Panell esquerra (equip local)
        JPanel pLocal = crearPanellEquip(true);
        // Panell central (info)
        JPanel pCentre = crearPanellCentral();
        // Panell dreta (equip visitant)
        JPanel pVisit = crearPanellEquip(false);

        p.add(pLocal,   BorderLayout.WEST);
        p.add(pCentre,  BorderLayout.CENTER);
        p.add(pVisit,   BorderLayout.EAST);
        return p;
    }

    private JPanel crearPanellEquip(boolean esLocal) {
        JPanel p = new JPanel(new GridLayout(3, 1, 0, 0));
        p.setOpaque(false);
        p.setPreferredSize(new Dimension(180, 0));
        p.setBorder(new EmptyBorder(8, 12, 8, 12));

        JLabel nomLbl = new JLabel(
            esLocal ? partit.getEquipLocal().getNom() : partit.getEquipVisitant().getNom(),
            esLocal ? SwingConstants.LEFT : SwingConstants.RIGHT
        );
        nomLbl.setFont(new Font("SansSerif", Font.BOLD, 14));
        nomLbl.setForeground(esLocal ? LOCAL_C : VISIT_C);

        JLabel scoreLbl = new JLabel("0", esLocal ? SwingConstants.LEFT : SwingConstants.RIGHT);
        scoreLbl.setFont(new Font("SansSerif", Font.BOLD, 36));
        scoreLbl.setForeground(Color.WHITE);

        JProgressBar bar = new JProgressBar(0, 100);
        bar.setValue(100);
        bar.setForeground(esLocal ? LOCAL_C : VISIT_C);
        bar.setBackground(new Color(40, 50, 70));
        bar.setBorderPainted(false);
        bar.setPreferredSize(new Dimension(0, 5));

        if (esLocal) { lblNomLocal = nomLbl; lblScoreLocal = scoreLbl; barLocal = bar; }
        else         { lblNomVisit = nomLbl; lblScoreVisit = scoreLbl; barVisit = bar; }

        p.add(nomLbl);
        p.add(scoreLbl);
        p.add(bar);
        return p;
    }

    private JPanel crearPanellCentral() {
        JPanel p = new JPanel(new GridLayout(3, 1, 0, 2));
        p.setOpaque(false);
        p.setBorder(new EmptyBorder(10, 0, 6, 0));

        JLabel lblTitol = new JLabel("HOQUEI PATINS", SwingConstants.CENTER);
        lblTitol.setFont(new Font("SansSerif", Font.BOLD, 11));
        lblTitol.setForeground(TEXT_DIM);

        lblInfo = new JLabel("P1 · T1/10", SwingConstants.CENTER);
        lblInfo.setFont(new Font("SansSerif", Font.BOLD, 14));
        lblInfo.setForeground(TEXT_MAIN);

        JLabel sep = new JLabel("VS", SwingConstants.CENTER);
        sep.setFont(new Font("SansSerif", Font.BOLD, 20));
        sep.setForeground(new Color(80, 100, 140));

        p.add(lblTitol);
        p.add(sep);
        p.add(lblInfo);
        return p;
    }

    // ═══════════════════════════════════════
    //  PANELL INFERIOR (missatge + botons)
    // ═══════════════════════════════════════

    private JPanel crearPanellInferior() {
        JPanel p = new JPanel(new BorderLayout(0, 0));
        p.setBackground(BG);

        // Missatge de torn
        lblMissatge = new JLabel("Comença el partit!", SwingConstants.CENTER);
        lblMissatge.setFont(new Font("SansSerif", Font.ITALIC, 13));
        lblMissatge.setForeground(TEXT_DIM);
        lblMissatge.setBorder(new EmptyBorder(6, 10, 4, 10));
        p.add(lblMissatge, BorderLayout.NORTH);

        // Botons
        panellBotons = new JPanel(new GridLayout(1, 3, 8, 0));
        panellBotons.setBackground(BG);
        panellBotons.setBorder(new EmptyBorder(4, 12, 10, 12));
        p.add(panellBotons, BorderLayout.CENTER);

        return p;
    }

    // ═══════════════════════════════════════
    //  ACTUALITZACIÓ
    // ═══════════════════════════════════════

    public void actualitzarUI() {
        Equip  local   = partit.getEquipLocal();
        Equip  visitant = partit.getEquipVisitant();
        Jugador jl = local.getJugador();
        Jugador jv = visitant.getJugador();

        lblScoreLocal.setText(String.valueOf(local.getGols()));
        lblScoreVisit.setText(String.valueOf(visitant.getGols()));
        lblInfo.setText("P" + partit.getPeriode() + "  ·  T" +
                        partit.getTornsDinsPeriode() + "/10");
        barLocal.setValue(jl.getEnergia());
        barVisit.setValue(jv.getEnergia());
        lblMissatge.setText(partit.getUltimMissatge());

        actualitzarBotons();
        canvas.repaint();
    }

    private void actualitzarBotons() {
        panellBotons.removeAll();
        boolean teP = partit.isPossessioLocal();

        if (teP) {
            panellBotons.add(crearBoto("TIRAR",     "Tira a porteria  (−20⚡)",  AccioJoc.TIRAR,        LOCAL_C));
            panellBotons.add(crearBoto("PASSAR",    "Passada preparatòria (−10⚡)", AccioJoc.PASSAR,    BTN_PASS));
            panellBotons.add(crearBoto("DESCANSAR", "Recupera energia (+25⚡)",   AccioJoc.DESCANSAR_ATAC, BTN_REST));
        } else {
            panellBotons.add(crearBoto("BLOQUEJAR",  "Bloca el tir  (−15⚡)",      AccioJoc.BLOQUEJAR,   VISIT_C));
            panellBotons.add(crearBoto("PRESSIONAR", "Roba la pilota (−20⚡)",     AccioJoc.PRESSIONAR,  new Color(130, 40, 160)));
            panellBotons.add(crearBoto("DESCANSAR",  "Recupera energia (+20⚡)",   AccioJoc.DESCANSAR_DEF, BTN_REST));
        }

        panellBotons.revalidate();
        panellBotons.repaint();
    }

    private JButton crearBoto(String titol, String subtitol, AccioJoc accio, Color color) {
        JButton btn = new JButton() {
            @Override
            protected void paintComponent(Graphics g) {
                Graphics2D g2 = (Graphics2D) g;
                g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
                Color base = blocatBotons ? new Color(50, 55, 70) : color;
                Color top  = base.brighter();
                GradientPaint gp = new GradientPaint(0, 0, top, 0, getHeight(), base);
                g2.setPaint(gp);
                g2.fillRoundRect(0, 0, getWidth(), getHeight(), 12, 12);
                if (getModel().isPressed()) {
                    g2.setColor(new Color(0, 0, 0, 60));
                    g2.fillRoundRect(0, 0, getWidth(), getHeight(), 12, 12);
                }
                // Títol
                g2.setFont(new Font("SansSerif", Font.BOLD, 14));
                g2.setColor(Color.WHITE);
                FontMetrics fm = g2.getFontMetrics();
                g2.drawString(titol, getWidth() / 2 - fm.stringWidth(titol) / 2, getHeight() / 2 - 4);
                // Subtítol
                g2.setFont(new Font("SansSerif", Font.PLAIN, 10));
                g2.setColor(new Color(255, 255, 255, 180));
                FontMetrics fm2 = g2.getFontMetrics();
                g2.drawString(subtitol, getWidth() / 2 - fm2.stringWidth(subtitol) / 2, getHeight() / 2 + 12);
            }
        };
        btn.setPreferredSize(new Dimension(0, 58));
        btn.setBorderPainted(false);
        btn.setFocusPainted(false);
        btn.setContentAreaFilled(false);
        btn.setCursor(blocatBotons ? Cursor.getDefaultCursor() : Cursor.getPredefinedCursor(Cursor.HAND_CURSOR));
        if (!blocatBotons) {
            btn.addActionListener(e -> processarAccio(accio));
        }
        return btn;
    }

    // ═══════════════════════════════════════
    //  LÒGICA D'ACCIÓ
    // ═══════════════════════════════════════

    public void processarAccio(AccioJoc accio) {
        if (partit.haAcabat() || blocatBotons) return;
        blocatBotons = true;
        actualitzarBotons();

        boolean eraPossessioLocal = partit.isPossessioLocal();
        partit.executarAccio(accio);

        TipusEvent ev = partit.getUltimEvent();
        boolean esGol = ev == TipusEvent.GOL_LOCAL || ev == TipusEvent.GOL_VISITANT;
        boolean esTir = esGol || ev == TipusEvent.TIR_FALLAT;

        Color colorEvent = switch (ev) {
            case GOL_LOCAL     -> new Color(255, 220, 50);
            case GOL_VISITANT  -> new Color(255, 80, 80);
            case BLOQUEIG      -> new Color(80, 180, 255);
            case ROBADA        -> new Color(180, 80, 255);
            default            -> new Color(200, 210, 230);
        };

        String textEvent = switch (ev) {
            case GOL_LOCAL    -> "⚽ GOL!";
            case GOL_VISITANT -> "⚽ GOL RIVAL!";
            case BLOQUEIG     -> "🛡 BLOQUEIG!";
            case ROBADA       -> "⚡ ROBADA!";
            case PASSADA      -> "↔ PASSADA!";
            case DESCANS      -> "💤 DESCANS";
            default           -> "";
        };

        if (esTir) {
            canvas.animarTir(esGol, eraPossessioLocal, () -> {
                if (!esGol) canvas.resetPuck();
                if (!textEvent.isEmpty()) canvas.mostrarEvent(textEvent, colorEvent);
                finalitzarTorn();
            });
        } else {
            if (!textEvent.isEmpty()) canvas.mostrarEvent(textEvent, colorEvent);
            Timer delay = new Timer(400, e -> { finalitzarTorn(); });
            delay.setRepeats(false);
            delay.start();
        }
    }

    private void finalitzarTorn() {
        if (partit.haAcabat()) {
            mostrarResultat();
        } else {
            blocatBotons = false;
            actualitzarUI();
        }
    }

    public void mostrarResultat() {
        Equip  l = partit.getEquipLocal();
        Equip  v = partit.getEquipVisitant();
        Partit.Resultat r = partit.obtenirResultat();

        String msg = switch (r) {
            case VICTORIA_LOCAL     -> "🏆 VICTÒRIA! " + l.getNom() + " guanya!";
            case VICTORIA_VISITANT  -> "💀 DERROTA! " + v.getNom() + " ha guanyat.";
            case EMPAT              -> "🤝 EMPAT! " + l.getGols() + " – " + v.getGols();
            default                 -> "";
        };
        lblMissatge.setText(msg);
        lblMissatge.setForeground(r == Partit.Resultat.VICTORIA_LOCAL
            ? new Color(255, 220, 50) : TEXT_MAIN);

        panellBotons.removeAll();
        JButton btnR = new JButton("TORNAR A JUGAR") {
            @Override
            protected void paintComponent(Graphics g) {
                Graphics2D g2 = (Graphics2D) g;
                g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
                GradientPaint gp = new GradientPaint(0, 0, new Color(40, 140, 60), 0, getHeight(), new Color(20, 90, 40));
                g2.setPaint(gp);
                g2.fillRoundRect(0, 0, getWidth(), getHeight(), 12, 12);
                g2.setFont(new Font("SansSerif", Font.BOLD, 16));
                g2.setColor(Color.WHITE);
                FontMetrics fm = g2.getFontMetrics();
                String t = "🔄  TORNAR A JUGAR";
                g2.drawString(t, getWidth() / 2 - fm.stringWidth(t) / 2, getHeight() / 2 + 6);
            }
        };
        btnR.setBorderPainted(false);
        btnR.setFocusPainted(false);
        btnR.setContentAreaFilled(false);
        btnR.setCursor(Cursor.getPredefinedCursor(Cursor.HAND_CURSOR));
        btnR.addActionListener(e -> {
            Window w = SwingUtilities.getWindowAncestor(this);
            if (w != null) w.dispose();
            GameWindow.iniciar();
        });
        panellBotons.add(new JLabel());
        panellBotons.add(btnR);
        panellBotons.add(new JLabel());
        panellBotons.revalidate();
        panellBotons.repaint();
    }
}
