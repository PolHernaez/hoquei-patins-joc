package logic;

import model.AccioJoc;
import model.Jugador;
import model.Partit;
import java.util.Random;

public class IAController {
    private final Random rng = new Random();

    public AccioJoc decideixAccio(Partit p) {
        Jugador j = p.getEquipVisitant().getJugador();
        if (j.getEnergia() < 20) return AccioJoc.DESCANSAR_ATAC;
        if (j.getEnergia() > 70) return AccioJoc.TIRAR;
        int r = rng.nextInt(10);
        if (r < 5) return AccioJoc.TIRAR;
        if (r < 8) return AccioJoc.PASSAR;
        return AccioJoc.DESCANSAR_ATAC;
    }

    public AccioJoc decideixDefensa(Partit p) {
        Jugador j = p.getEquipVisitant().getJugador();
        if (j.getEnergia() < 20) return AccioJoc.DESCANSAR_DEF;
        int r = rng.nextInt(10);
        if (r < 4) return AccioJoc.BLOQUEJAR;
        if (r < 7) return AccioJoc.PRESSIONAR;
        return AccioJoc.DESCANSAR_DEF;
    }
}
