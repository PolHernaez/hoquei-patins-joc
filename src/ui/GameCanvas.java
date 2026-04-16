package ui;

import model.Partit;

import javax.swing.*;
import java.awt.*;
import java.awt.geom.*;

public class GameCanvas extends JPanel {

    // ── Dimensions pista ──────────────────────────────────────────────
    private static final int RX = 40, RY = 25, RW = 520, RH = 270;
    private static final int CX = RX + RW / 2;
    private static final int CY = RY + RH / 2;

    // Porteries
    private static final int GW = 18, GH = 54;
    private static final int LGX = RX + 5,         LGY = CY - GH / 2;
    private static final int RGX = RX + RW - GW - 5, RGY = CY - GH / 2;

    // Posicions jugadors
    private static final int LAX = RX + 200, LAY = CY;   // local atacant
    private static final int LGK = RX + 55,  LGY2 = CY; // local porter
    private static final int VAX = RX + 320, VAY = CY;   // visitant atacant
    private static final int VGK = RX + RW - 55, VGY2 = CY; // visitant porter

    // ── Colors ────────────────────────────────────────────────────────
    private static final Color ICE      = new Color(210, 230, 245);
    private static final Color ICE2     = new Color(195, 218, 238);
    private static final Color BORDER   = new Color(140, 180, 215);
    private static final Color C_LOCAL  = new Color(210, 30, 30);
    private static final Color C_VISIT  = new Color(20, 70, 200);
    private static final Color C_LINES  = new Color(180, 40, 40);
    private static final Color C_CLINE  = new Color(30, 80, 190);
    private static final Color PUCK_C   = new Color(25, 25, 25);

    private final Partit partit;

    // ── Estat puck ────────────────────────────────────────────────────
    private float px, py;           // posició puck
    private float pStartX, pStartY, pEndX, pEndY;
    private float animT = 1f;
    private Timer animTimer;

    // ── Estat event text ──────────────────────────────────────────────
    private String eventText  = "";
    private int    eventAlpha = 0;
    private Color  eventColor = Color.YELLOW;
    private Timer  fadeTimer;

    // ── Estat goal flash ──────────────────────────────────────────────
    private int   flashAlpha = 0;
    private Color flashColor = new Color(255, 220, 0);
    private Timer flashTimer;

    public GameCanvas(Partit partit) {
        this.partit = partit;
        setPreferredSize(new Dimension(RX * 2 + RW, RY * 2 + RH));
        setBackground(new Color(12, 18, 30));
        px = CX;
        py = CY;
    }

    // ═════════════════════════════════════════════════════════════════
    //  PINTAT
    // ═════════════════════════════════════════════════════════════════

    @Override
    protected void paintComponent(Graphics g) {
        super.paintComponent(g);
        Graphics2D g2 = (Graphics2D) g;
        g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING,      RenderingHints.VALUE_ANTIALIAS_ON);
        g2.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING, RenderingHints.VALUE_TEXT_ANTIALIAS_ON);
        g2.setRenderingHint(RenderingHints.KEY_RENDERING,         RenderingHints.VALUE_RENDER_QUALITY);

        pintarFons(g2);
        pintarPista(g2);
        pintarLinies(g2);
        pintarPorteries(g2);
        pintarJugadors(g2);
        pintarPuck(g2);
        pintarFlash(g2);
        pintarEventText(g2);
    }

    private void pintarFons(Graphics2D g2) {
        // Fons fosc fora de la pista
        g2.setColor(new Color(12, 18, 30));
        g2.fillRect(0, 0, getWidth(), getHeight());

        // Ombra pista
        g2.setColor(new Color(0, 0, 0, 80));
        g2.fillRoundRect(RX + 6, RY + 8, RW, RH, 80, 80);
    }

    private void pintarPista(Graphics2D g2) {
        // Gel: degradat suau
        GradientPaint gp = new GradientPaint(RX, RY, ICE, RX, RY + RH, ICE2);
        g2.setPaint(gp);
        g2.fillRoundRect(RX, RY, RW, RH, 80, 80);

        // Marc pista
        g2.setColor(BORDER);
        g2.setStroke(new BasicStroke(4f, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND));
        g2.drawRoundRect(RX, RY, RW, RH, 80, 80);
    }

    private void pintarLinies(Graphics2D g2) {
        // Zones de gol (vermell)
        g2.setColor(new Color(C_LINES.getRed(), C_LINES.getGreen(), C_LINES.getBlue(), 60));
        g2.fillRect(RX + 1, RY + 1, 120, RH - 1);
        g2.fillRect(RX + RW - 120, RY + 1, 119, RH - 1);
        // re-aplica clip de la pista
        g2.setClip(new RoundRectangle2D.Float(RX, RY, RW, RH, 80, 80));

        g2.setColor(new Color(C_LINES.getRed(), C_LINES.getGreen(), C_LINES.getBlue(), 60));
        g2.fillRect(RX + 1, RY + 1, 120, RH - 1);
        g2.fillRect(RX + RW - 120, RY + 1, 119, RH - 1);
        g2.setClip(null);

        // Línia vermella zona (esquerra)
        g2.setColor(C_LINES);
        g2.setStroke(new BasicStroke(3f));
        g2.drawLine(RX + 120, RY + 10, RX + 120, RY + RH - 10);
        g2.drawLine(RX + RW - 120, RY + 10, RX + RW - 120, RY + RH - 10);

        // Línia central blava
        g2.setColor(C_CLINE);
        g2.setStroke(new BasicStroke(4f));
        g2.drawLine(CX, RY + 10, CX, RY + RH - 10);

        // Cercle central
        g2.setColor(new Color(C_CLINE.getRed(), C_CLINE.getGreen(), C_CLINE.getBlue(), 120));
        g2.setStroke(new BasicStroke(2.5f));
        g2.drawOval(CX - 45, CY - 45, 90, 90);

        // Punt central
        g2.setColor(C_LINES);
        g2.fillOval(CX - 5, CY - 5, 10, 10);

        // Punts de cara-off
        for (int fx : new int[]{RX + 80, RX + RW - 80}) {
            for (int fy : new int[]{RY + 60, RY + RH - 60}) {
                g2.setColor(C_LINES);
                g2.fillOval(fx - 4, fy - 4, 8, 8);
                g2.setColor(new Color(C_LINES.getRed(), C_LINES.getGreen(), C_LINES.getBlue(), 80));
                g2.setStroke(new BasicStroke(1.5f));
                g2.drawOval(fx - 18, fy - 18, 36, 36);
            }
        }

        // Zona porter (crease)
        g2.setColor(new Color(100, 160, 220, 100));
        g2.fillArc(LGX + GW, LGY - 20, 50, GH + 40, 270, 180);
        g2.fillArc(RGX - 50, RGY - 20, 50, GH + 40, 90, 180);
    }

    private void pintarPorteries(Graphics2D g2) {
        // Porteria esquerra (local la defensa)
        g2.setColor(new Color(255, 255, 255, 40));
        g2.fillRect(LGX, LGY, GW, GH);
        g2.setColor(Color.WHITE);
        g2.setStroke(new BasicStroke(2.5f));
        g2.drawRect(LGX, LGY, GW, GH);
        // Pal horitzontal
        g2.drawLine(LGX, LGY, LGX + GW, LGY);
        g2.drawLine(LGX, LGY + GH, LGX + GW, LGY + GH);

        // Porteria dreta (visitant la defensa)
        g2.setColor(new Color(255, 255, 255, 40));
        g2.fillRect(RGX, RGY, GW, GH);
        g2.setColor(Color.WHITE);
        g2.drawRect(RGX, RGY, GW, GH);
        g2.drawLine(RGX, RGY, RGX + GW, RGY);
        g2.drawLine(RGX, RGY + GH, RGX + GW, RGY + GH);
    }

    private void pintarJugadors(Graphics2D g2) {
        boolean local = partit.isPossessioLocal();
        if (local) {
            pintarJugador(g2, LAX, LAY, C_LOCAL,
                          abreviar(partit.getEquipLocal().getJugador().getNom()), true);
            pintarJugador(g2, VGK, VGY2, C_VISIT, "GK", false);
            pintarJugador(g2, LGK, LGY2, C_LOCAL, "GK", false);
        } else {
            pintarJugador(g2, VAX, VAY, C_VISIT, "BOT", true);
            pintarJugador(g2, LGK, LGY2, C_LOCAL, "GK", false);
            pintarJugador(g2, VGK, VGY2, C_VISIT, "GK", false);
        }
    }

    private void pintarJugador(Graphics2D g2, int x, int y, Color color, String etiqueta, boolean teP) {
        int r = 20;

        // Ombra
        g2.setColor(new Color(0, 0, 0, 70));
        g2.fillOval(x - r + 4, y - r + 6, r * 2, r * 2);

        // Aura si té possessió
        if (teP) {
            for (int i = 3; i >= 1; i--) {
                g2.setColor(new Color(255, 240, 80, 25 * i));
                g2.fillOval(x - r - i * 5, y - r - i * 5, (r + i * 5) * 2, (r + i * 5) * 2);
            }
        }

        // Cos (jersey)
        g2.setColor(color);
        g2.fillOval(x - r, y - r, r * 2, r * 2);

        // Reflexe llum al jersey
        GradientPaint shine = new GradientPaint(
            x - r + 4, y - r + 4, new Color(255, 255, 255, 90),
            x, y, new Color(255, 255, 255, 0)
        );
        g2.setPaint(shine);
        g2.fillOval(x - r, y - r, r * 2, r * 2);

        // Vora blanca
        g2.setColor(Color.WHITE);
        g2.setStroke(new BasicStroke(2f));
        g2.drawOval(x - r, y - r, r * 2, r * 2);

        // Etiqueta (nom curt)
        g2.setColor(Color.WHITE);
        g2.setFont(new Font("SansSerif", Font.BOLD, 10));
        FontMetrics fm = g2.getFontMetrics();
        g2.drawString(etiqueta, x - fm.stringWidth(etiqueta) / 2, y + 4);

        // Estick
        if (teP) {
            g2.setColor(new Color(130, 80, 30));
            g2.setStroke(new BasicStroke(3f, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND));
            boolean esLocal = color.equals(C_LOCAL);
            if (esLocal) g2.drawLine(x + r - 6, y + 6, x + r + 14, y + 18);
            else         g2.drawLine(x - r + 6, y + 6, x - r - 14, y + 18);
        }
    }

    private void pintarPuck(Graphics2D g2) {
        int ix = (int) px, iy = (int) py;
        // Ombra
        g2.setColor(new Color(0, 0, 0, 90));
        g2.fillOval(ix - 8, iy - 2, 16, 9);
        // Puck
        g2.setColor(PUCK_C);
        g2.fillOval(ix - 7, iy - 5, 14, 9);
        // Reflexe
        g2.setColor(new Color(80, 80, 80, 180));
        g2.fillOval(ix - 3, iy - 4, 5, 3);
    }

    private void pintarFlash(Graphics2D g2) {
        if (flashAlpha <= 0) return;
        g2.setColor(new Color(flashColor.getRed(), flashColor.getGreen(), flashColor.getBlue(), flashAlpha));
        g2.fillRoundRect(RX, RY, RW, RH, 80, 80);
    }

    private void pintarEventText(Graphics2D g2) {
        if (eventText.isEmpty() || eventAlpha <= 0) return;
        Font font = new Font("SansSerif", Font.BOLD, 30);
        g2.setFont(font);
        FontMetrics fm = g2.getFontMetrics();
        int tw = fm.stringWidth(eventText);
        int tx = getWidth() / 2 - tw / 2;
        int ty = RY + RH / 2 + 12;
        // Ombra
        g2.setColor(new Color(0, 0, 0, eventAlpha / 2));
        g2.drawString(eventText, tx + 3, ty + 3);
        // Text
        g2.setColor(new Color(eventColor.getRed(), eventColor.getGreen(), eventColor.getBlue(), eventAlpha));
        g2.drawString(eventText, tx, ty);
    }

    // ═════════════════════════════════════════════════════════════════
    //  ANIMACIONS
    // ═════════════════════════════════════════════════════════════════

    public void animarTir(boolean gol, boolean eraPossessioLocal, Runnable onEnd) {
        pStartX = eraPossessioLocal ? LAX : VAX;
        pStartY = eraPossessioLocal ? LAY : VAY;
        px = pStartX; py = pStartY;

        float offset = (float)(Math.random() * 30 - 15);
        if (eraPossessioLocal) {
            pEndX = gol ? RGX + GW / 2f : RX + RW - 80;
            pEndY = RGY + GH / 2f + offset;
        } else {
            pEndX = gol ? LGX + GW / 2f : RX + 80;
            pEndY = LGY + GH / 2f + offset;
        }

        animT = 0;
        if (animTimer != null) animTimer.stop();
        animTimer = new Timer(14, e -> {
            animT += 0.07f;
            // Easeing quadràtic
            float t = animT < 1 ? animT : 1;
            float ease = t * (2 - t);
            px = pStartX + (pEndX - pStartX) * ease;
            py = pStartY + (pEndY - pStartY) * ease;
            repaint();
            if (animT >= 1f) {
                ((Timer) e.getSource()).stop();
                if (gol) flashGol(eraPossessioLocal);
                onEnd.run();
            }
        });
        animTimer.start();
    }

    private void flashGol(boolean esLocal) {
        flashColor = esLocal ? new Color(255, 220, 50) : new Color(200, 50, 50);
        flashAlpha = 180;
        if (flashTimer != null) flashTimer.stop();
        flashTimer = new Timer(20, e -> {
            flashAlpha -= 12;
            if (flashAlpha <= 0) { flashAlpha = 0; ((Timer) e.getSource()).stop(); }
            repaint();
        });
        flashTimer.start();
    }

    public void mostrarEvent(String text, Color color) {
        eventText  = text;
        eventColor = color;
        eventAlpha = 255;
        if (fadeTimer != null) fadeTimer.stop();
        fadeTimer = new Timer(35, e -> {
            eventAlpha -= 7;
            if (eventAlpha <= 0) { eventAlpha = 0; ((Timer) e.getSource()).stop(); }
            repaint();
        });
        fadeTimer.start();
    }

    public void resetPuck() {
        px = CX; py = CY;
        repaint();
    }

    // Helper
    private String abreviar(String nom) {
        String[] parts = nom.split(" ");
        if (parts.length >= 2) return parts[0].substring(0, 1) + "." + parts[1].substring(0, Math.min(4, parts[1].length()));
        return nom.length() > 5 ? nom.substring(0, 5) : nom;
    }
}
