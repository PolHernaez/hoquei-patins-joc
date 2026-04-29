package ui;

import javafx.animation.*;
import javafx.application.Application;
import javafx.geometry.*;
import javafx.scene.*;
import javafx.scene.control.*;
import javafx.scene.input.*;
import javafx.scene.layout.*;
import javafx.scene.paint.*;
import javafx.scene.shape.*;
import javafx.scene.transform.*;
import javafx.stage.Stage;
import javafx.util.Duration;
import java.util.*;

/**
 * Hoquei Patins 3D – DAM1
 * Mecànica Mini Soccer Star: torns amb temps aturat, fletxa d'apuntament,
 * drag per apuntar + alliberar per xutar. Vista 3D isomètrica (no 3a persona).
 */
public class GameWindow extends Application {

    // ═══ DIMENSIONS ═══════════════════════════════════
    static final double FW = 480, FH = 240;  // camp
    static final double BR = 9;               // radi pilota
    static final double GZ = 35, GD = 28, GH = 34;  // porteria

    // ═══ FÍSICA ═══════════════════════════════════════
    static final double SPD_N=360, SPD_C=290, SPD_P=500, FRIC=0.978;

    // ═══ ENUMS ════════════════════════════════════════
    enum Phase { MYTURN, SHOOTING, AI_TURN, GOAL, OVER }
    enum Shot  { NORMAL, CURVE, POWER }

    Phase phase   = Phase.MYTURN;
    Shot  shotTyp = Shot.NORMAL;

    // ═══ POSICIONS JUGADORS ═══════════════════════════
    // local[0]=GK, [1]=DEF, [2]=FW(humà)  /  rival[0]=GK, [1]=DEF, [2]=FW
    double[] lx=new double[3], lz=new double[3];
    double[] ltx=new double[3], ltz=new double[3];
    double[] rx=new double[3], rz=new double[3];
    double[] rtx=new double[3], rtz=new double[3];

    boolean humanBall=false, rivalBall=false;
    int rHolder=-1;

    // ═══ PILOTA ═══════════════════════════════════════
    double bx, bz, bvx, bvz, cfx, cfz;
    boolean ballFree=false;

    // ═══ APUNTAMENT ═══════════════════════════════════
    double aimAng=0, aimPow=0.6;
    double msPx, msPy, msAng, msPow;
    double totalDrag=0;
    boolean didDrag=false;

    // ═══ JOC ══════════════════════════════════════════
    int scoreL, scoreR, rewinds=3;
    double timeLeft=120;
    double svBx, svBz, svHx, svHz;

    // ═══ CAMERA ═══════════════════════════════════════
    double camAngle=0;
    Rotate camOrbit = new Rotate(0, Rotate.Y_AXIS);
    Group camPivot;
    PerspectiveCamera cam;

    // ═══ NODES ════════════════════════════════════════
    Group root3D; SubScene sub3D; Box floorBox;
    Group ballNode, aimGroup, auraGroup;
    Rotate aimYaw = new Rotate(0, Rotate.Y_AXIS);
    Group[] lN=new Group[3], rN=new Group[3];

    // ═══ UI ═══════════════════════════════════════════
    Label lblSL, lblSR, lblTime, lblMsg;
    Button bNorm, bCurv, bPow, bPass, bShoot, bRew;
    long lastNs=-1;
    AnimationTimer loop;

    // ═══════════════════════════════════════════════════
    @Override
    public void start(Stage stage) {
        root3D = new Group();
        sub3D  = new SubScene(root3D, 700, 430, true, SceneAntialiasing.BALANCED);
        sub3D.setFill(Color.rgb(4, 6, 14));

        buildCam();
        buildField();
        buildGoals();
        buildPlayers();
        buildBall();
        buildAim();
        buildAura();
        buildLights();

        BorderPane root = new BorderPane();
        root.setStyle("-fx-background-color:#04060e;");
        root.setTop(buildHUD());
        root.setCenter(new StackPane(sub3D));
        root.setBottom(buildCtrl());

        Scene scene = new Scene(root, 700, 625);
        // addEventFilter: tecles funcionen sempre, fins i tot si botons tenen focus
        scene.addEventFilter(KeyEvent.KEY_PRESSED, this::onKey);
        sub3D.setOnMousePressed(this::onPress);
        sub3D.setOnMouseDragged(this::onDrag);
        sub3D.setOnMouseReleased(this::onRelease);

        stage.setTitle("Hoquei Patins – Pol Hernáez (DAM1)");
        stage.setScene(scene);
        stage.setResizable(false);
        stage.show();

        // initPos SEMPRE després de buildHUD (els Labels ja existeixen)
        initPos(true);
        startLoop();
    }

    // ─── CÀMERA ISOMÈTRICA FIXA ──────────────────────
    // Vista de tot el camp des de dalt-darrere, estàtica
    // (camAngle permet rotar amb fletxes del teclat)
    void buildCam() {
        cam = new PerspectiveCamera(true);
        cam.setFieldOfView(52);
        cam.setNearClip(1);
        cam.setFarClip(3000);
        // Inclinada cap avall 46°, allunyada 660 unitats
        cam.getTransforms().addAll(
            new Rotate(-46, Rotate.X_AXIS),
            new Translate(0, 0, -660)
        );
        camPivot = new Group(cam);
        camPivot.getTransforms().add(camOrbit);
        root3D.getChildren().add(camPivot);
        sub3D.setCamera(cam);
    }

    void tickCam() {
        // Pivot centrat al camp (no segueix el jugador – vista total)
        camPivot.setTranslateX(0);
        camPivot.setTranslateZ(0);
        camOrbit.setAngle(camAngle);
    }

    // ─── CAMP DE PARQUET ─────────────────────────────
    void buildField() {
        // Terra de parquet de fusta
        floorBox = new Box(FW, 4, FH);
        floorBox.setTranslateY(2);  // centre a Y=2, superfície a Y=0
        PhongMaterial fm = pm(Color.rgb(190, 148, 85));
        fm.setSpecularColor(Color.rgb(220, 184, 118));
        fm.setSpecularPower(4);
        floorBox.setMaterial(fm);
        root3D.getChildren().add(floorBox);

        // Línies del camp (Y=0 = superfície del parquet)
        ab(4, 1, FH,      0, 0, 0, Color.rgb(25,  65, 215)); // central
        ab(4, 1, FH, -FW/4, 0, 0, Color.rgb(190, 25, 25));  // zona E
        ab(4, 1, FH,  FW/4, 0, 0, Color.rgb(190, 25, 25));  // zona O

        // Cercle i punt central
        Cylinder cc = new Cylinder(55, 1); cc.setMaterial(pm(Color.rgb(25, 65, 215))); root3D.getChildren().add(cc);
        Cylinder cd = new Cylinder(9,  2); cd.setMaterial(pm(Color.rgb(190, 25, 25)));  root3D.getChildren().add(cd);

        // Punts cara-off (4 cantonades)
        for (int[] s : new int[][]{{-1,-1},{-1,1},{1,-1},{1,1}}) {
            Cylinder d = new Cylinder(6, 1.5);
            d.setMaterial(pm(Color.rgb(190, 25, 25)));
            d.setTranslateX(s[0]*FW/4); d.setTranslateZ(s[1]*FH/3.5);
            root3D.getChildren().add(d);
        }

        // Bandes de roller hockey: blanques amb franja vermella
        double bh = 36, by = -bh/2;
        Color W = Color.rgb(232, 236, 248), R = Color.rgb(172, 18, 18);
        ab(FW+28, bh, 9,          0, by, -FH/2-4.5, W);
        ab(FW+28, bh, 9,          0, by,  FH/2+4.5, W);
        ab(9, bh, FH+9, -FW/2-4.5, by,  0,          W);
        ab(9, bh, FH+9,  FW/2+4.5, by,  0,          W);
        ab(FW+28, 7, 10,         0, by+bh/2-12, -FH/2-4.5, R);
        ab(FW+28, 7, 10,         0, by+bh/2-12,  FH/2+4.5, R);
        ab(10, 7, FH+9, -FW/2-4.5,  by+bh/2-12,  0,        R);
        ab(10, 7, FH+9,  FW/2+4.5,  by+bh/2-12,  0,        R);
    }

    // ─── PORTERIES ───────────────────────────────────
    void buildGoals() {
        root3D.getChildren().addAll(makeGoal(-FW/2, true), makeGoal(FW/2, false));
    }

    Group makeGoal(double gx, boolean local) {
        Color c  = local ? Color.rgb(205, 22, 22) : Color.rgb(14, 52, 212);
        Color nc = local ? Color.rgb(44, 4, 4)    : Color.rgb(4, 6, 44);
        PhongMaterial m = pm(c);
        Box lp = new Box(6, GH, 6); lp.setTranslateZ(-GZ); lp.setTranslateY(-GH/2); lp.setMaterial(m);
        Box rp = new Box(6, GH, 6); rp.setTranslateZ( GZ); rp.setTranslateY(-GH/2); rp.setMaterial(m);
        Box tr = new Box(6, 6, GZ*2+6);     tr.setTranslateY(-GH); tr.setMaterial(m);
        double rxv = local ? -GD/2 : GD/2;
        Box r1 = new Box(GD,6,6); r1.setTranslateX(rxv); r1.setTranslateZ(-GZ); r1.setTranslateY(-GH); r1.setMaterial(m);
        Box r2 = new Box(GD,6,6); r2.setTranslateX(rxv); r2.setTranslateZ( GZ); r2.setTranslateY(-GH); r2.setMaterial(m);
        Box bk = new Box(6, GH, GZ*2+6); bk.setTranslateX(rxv*2); bk.setTranslateY(-GH/2); bk.setMaterial(m);
        Box net= new Box(GD, GH-5, GZ*2); net.setTranslateX(rxv); net.setTranslateY(-GH/2+2.5); net.setMaterial(pm(nc));
        Group g = new Group(lp,rp,tr,r1,r2,bk,net);
        g.setTranslateX(gx);
        return g;
    }

    // ─── JUGADORS BLOCKY (estil Roblox/MSS) ──────────
    // IMPORTANT: el node s'ubica a Y=0 (superfície del terra)
    // Tots els cossos van cap amunt (Y negativa en JavaFX 3D)
    void buildPlayers() {
        Color RED=Color.rgb(200,22,22), RS=Color.rgb(108,108,108), RH=Color.rgb(130,10,10);
        Color BLU=Color.rgb(14,54,212), BS=Color.rgb(78,78,78),   BH=Color.rgb(8,28,148);
        for (int i = 0; i < 3; i++) {
            lN[i] = blocky(RED, RS, (i==0)?Color.GOLD:RH, i==2);
            rN[i] = blocky(BLU, BS, (i==0)?Color.GOLD:BH, false);
            root3D.getChildren().addAll(lN[i], rN[i]);
        }
    }

    Group blocky(Color j, Color sh, Color hc, boolean isHuman) {
        // === PATINS (base, Y = 0 a -8) ===
        // Rodes (cilindres giratoris, a Y=-1 per estar just al terra)
        List<Node> wheels = new ArrayList<>();
        for (double sx : new double[]{-6.5, 6.5})
            for (double sz : new double[]{-8.5, -2.5, 2.5, 8.5}) {
                Cylinder w = new Cylinder(3.8, 5.5);
                w.setTranslateX(sx); w.setTranslateZ(sz); w.setTranslateY(-1);
                w.getTransforms().add(new Rotate(90, Rotate.X_AXIS));
                w.setMaterial(pm(Color.rgb(200, 20, 20))); // rodes vermelles
                wheels.add(w);
            }
        // Cos del pati (negre)
        Box sk1 = new Box(15, 7, 22); sk1.setTranslateX(-6.5); sk1.setTranslateY(-5); sk1.setMaterial(pm(Color.rgb(12,12,12)));
        Box sk2 = new Box(15, 7, 22); sk2.setTranslateX( 6.5); sk2.setTranslateY(-5); sk2.setMaterial(pm(Color.rgb(12,12,12)));

        // === CAMES (Y = -8 a -28) ===
        Box lL = new Box(13, 20, 13); lL.setTranslateX(-6.5); lL.setTranslateY(-18); lL.setMaterial(pm(sh));
        Box lR = new Box(13, 20, 13); lR.setTranslateX( 6.5); lR.setTranslateY(-18); lR.setMaterial(pm(sh));
        // Genolleres
        Box kL = new Box(15, 10, 15); kL.setTranslateX(-6.5); kL.setTranslateY(-14); kL.setMaterial(pm(Color.rgb(28,28,28)));
        Box kR = new Box(15, 10, 15); kR.setTranslateX( 6.5); kR.setTranslateY(-14); kR.setMaterial(pm(Color.rgb(28,28,28)));

        // === TORSO (Y = -28 a -52) ===
        Box body = new Box(30, 24, 18); body.setTranslateY(-40); body.setMaterial(pm(j));
        // Franja blanca horitzontal (número)
        Box stripe = new Box(30, 5, 19); stripe.setTranslateY(-37); stripe.setMaterial(pm(Color.WHITE));

        // === BRAÇOS (Y = -28 a -56) ===
        Box aL = new Box(11, 26, 12); aL.setTranslateX(-21); aL.setTranslateY(-40); aL.setMaterial(pm(j));
        Box aR = new Box(11, 26, 12); aR.setTranslateX( 21); aR.setTranslateY(-40); aR.setMaterial(pm(j));
        Box eL = new Box(13,  9, 13); eL.setTranslateX(-21); eL.setTranslateY(-46); eL.setMaterial(pm(Color.rgb(22,22,22)));
        Box eR = new Box(13,  9, 13); eR.setTranslateX( 21); eR.setTranslateY(-46); eR.setMaterial(pm(Color.rgb(22,22,22)));
        // Guants de hoquei (grans i negres)
        Box gL = new Box(15, 14, 14); gL.setTranslateX(-21); gL.setTranslateY(-56); gL.setMaterial(pm(Color.rgb(14,14,14)));
        Box gR = new Box(15, 14, 14); gR.setTranslateX( 21); gR.setTranslateY(-56); gR.setMaterial(pm(Color.rgb(14,14,14)));

        // === CAP (Y = -52 a -78, Roblox cube) ===
        Box head = new Box(32, 26, 30); head.setTranslateY(-63); head.setMaterial(pm(Color.rgb(225,175,132)));
        // Ulls i boca pixelats
        Box eyL = new Box(8, 7, 3); eyL.setTranslateX(-8); eyL.setTranslateY(-61); eyL.setTranslateZ(-15); eyL.setMaterial(pm(Color.rgb(16,9,4)));
        Box eyR = new Box(8, 7, 3); eyR.setTranslateX( 8); eyR.setTranslateY(-61); eyR.setTranslateZ(-15); eyR.setMaterial(pm(Color.rgb(16,9,4)));
        Box mth = new Box(12, 4, 3);  mth.setTranslateY(-68); mth.setTranslateZ(-15); mth.setMaterial(pm(Color.rgb(16,9,4)));

        // === CASC (Y = -52 a -82) ===
        Box hlm = new Box(38, 32, 36); hlm.setTranslateY(-65);
        PhongMaterial hm = new PhongMaterial(hc);
        hm.setSpecularColor(Color.WHITE); hm.setSpecularPower(65); hlm.setMaterial(hm);
        Box hst = new Box(38, 6, 37); hst.setTranslateY(-52); hst.setMaterial(pm(hc.brighter()));
        // Reixa (cage) – roller hockey
        Box cage = new Box(30, 22, 4); cage.setTranslateY(-66); cage.setTranslateZ(-18); cage.setMaterial(pm(Color.rgb(4,4,4)));
        List<Node> bars = new ArrayList<>();
        for (int bv : new int[]{-11,-4,4,11}) {
            Box b = new Box(3, 22, 4.5); b.setTranslateX(bv); b.setTranslateY(-66); b.setTranslateZ(-18);
            b.setMaterial(pm(Color.rgb(48,48,48))); bars.add(b);
        }

        // === ESTIC DE FUSTA + PALA ===
        Box shaft = new Box(8, 58, 8); shaft.setTranslateX(23); shaft.setTranslateY(-28);
        shaft.setMaterial(pm(Color.rgb(130, 80, 18)));
        shaft.getTransforms().add(new Rotate(-16, Rotate.Z_AXIS));
        Box blade = new Box(6, 6, 26); blade.setTranslateX(27); blade.setTranslateY(-4); blade.setTranslateZ(11);
        blade.setMaterial(pm(Color.rgb(58, 28, 7)));

        // === ANELL DAURAT (★ jugador humà) ===
        Cylinder ring = new Cylinder(24, 2.8); ring.setTranslateY(1.5);
        ring.setMaterial(pm(Color.rgb(255, 215, 0))); ring.setVisible(isHuman);

        // === OMBRA ===
        Cylinder shadow = new Cylinder(20, 1.2);
        shadow.setMaterial(pm(Color.rgb(10, 7, 3))); shadow.setTranslateY(1);

        Group g = new Group(shadow, sk1, sk2, kL, kR, lL, lR, body, stripe,
                            aL, aR, eL, eR, gL, gR, head, eyL, eyR, mth,
                            hlm, hst, cage, shaft, blade, ring);
        g.getChildren().addAll(wheels); g.getChildren().addAll(bars);
        return g;
    }

    // ─── PILOTA ──────────────────────────────────────
    void buildBall() {
        Sphere bs = new Sphere(BR);
        PhongMaterial bm = new PhongMaterial(Color.rgb(255, 110, 8));
        bm.setSpecularColor(Color.rgb(255, 198, 88)); bm.setSpecularPower(88); bs.setMaterial(bm);
        Cylinder stripe = new Cylinder(BR-2.5, 5.5); stripe.setMaterial(pm(Color.rgb(12, 12, 12)));
        Cylinder bsh = new Cylinder(BR+5, 1.5); bsh.setTranslateY(BR+0.5); bsh.setMaterial(pm(Color.rgb(10, 7, 3)));
        ballNode = new Group(bsh, bs, stripe);
        root3D.getChildren().add(ballNode);
    }

    // ─── FLETXA D'APUNTAMENT (discs plans al terra) ──
    // Discs (cylinders amb height=3) al terra → visibles des de càmera inclinada
    void buildAim() {
        Group inner = new Group();
        for (int i = 1; i <= 10; i++) {
            double t = (double)i / 10.0;
            Color c = (t<0.4) ? Color.rgb(35,215,60) : (t<0.7) ? Color.rgb(255,195,20) : Color.rgb(255,40,25);
            PhongMaterial dm = new PhongMaterial(c);
            dm.setSpecularColor(c.brighter()); dm.setSpecularPower(30);
            Cylinder disc = new Cylinder(8.5 - i*0.45, 3); // disc pla
            disc.setTranslateX(i * 16);
            disc.setTranslateY(1);   // just per sobre del terra
            disc.setMaterial(dm);
            inner.getChildren().add(disc);
        }
        // Punta de la fletxa (cub)
        Box tip = new Box(18, 5, 18); tip.setTranslateX(178); tip.setTranslateY(1);
        tip.setMaterial(pm(Color.rgb(255, 228, 30)));
        inner.getChildren().add(tip);

        inner.getTransforms().add(aimYaw);
        aimGroup = new Group(inner);
        aimGroup.setVisible(false);
        root3D.getChildren().add(aimGroup);
    }

    void refreshAim() {
        if (phase != Phase.MYTURN || !humanBall) { aimGroup.setVisible(false); return; }
        aimGroup.setTranslateX(bx);
        aimGroup.setTranslateZ(bz);
        aimGroup.setScaleX(0.25 + aimPow * 0.75);
        aimYaw.setAngle(-Math.toDegrees(aimAng));
        aimGroup.setVisible(true);
    }

    // ─── AURA (pulse quan és el torn) ────────────────
    void buildAura() {
        Cylinder ou = new Cylinder(30, 4.5); Cylinder mi = new Cylinder(20, 3);
        PhongMaterial o = new PhongMaterial(Color.rgb(50, 190, 255)); o.setSpecularColor(Color.WHITE); o.setSpecularPower(75); ou.setMaterial(o);
        PhongMaterial m = new PhongMaterial(Color.rgb(130, 220, 255)); m.setSpecularColor(Color.WHITE); m.setSpecularPower(75); mi.setMaterial(m);
        auraGroup = new Group(ou, mi);
        auraGroup.setTranslateY(1); auraGroup.setVisible(false);
        root3D.getChildren().add(auraGroup);
        Timeline pulse = new Timeline(
            new KeyFrame(Duration.ZERO,        new KeyValue(auraGroup.scaleXProperty(), 1.0), new KeyValue(auraGroup.scaleZProperty(), 1.0)),
            new KeyFrame(Duration.millis(500), new KeyValue(auraGroup.scaleXProperty(), 1.4), new KeyValue(auraGroup.scaleZProperty(), 1.4)),
            new KeyFrame(Duration.millis(1000),new KeyValue(auraGroup.scaleXProperty(), 1.0), new KeyValue(auraGroup.scaleZProperty(), 1.0)));
        pulse.setCycleCount(Animation.INDEFINITE); pulse.play();
    }

    // ─── LLUMS ───────────────────────────────────────
    void buildLights() {
        AmbientLight al = new AmbientLight(Color.rgb(112, 112, 112));
        PointLight p1 = new PointLight(Color.rgb(255, 245, 212)); p1.setTranslateY(-700); p1.setTranslateX(-90);
        PointLight p2 = new PointLight(Color.rgb(140, 172, 255)); p2.setTranslateY(-500); p2.setTranslateX(270); p2.setTranslateZ(-70);
        PointLight p3 = new PointLight(Color.rgb(255, 245, 212)); p3.setTranslateY(-700); p3.setTranslateX(90);  p3.setTranslateZ(90);
        root3D.getChildren().addAll(al, p1, p2, p3);
    }

    // ─── HUD ─────────────────────────────────────────
    HBox buildHUD() {
        HBox hud = new HBox(); hud.setStyle("-fx-background-color:linear-gradient(to bottom,#0d1830,#060d1c);");
        hud.setPadding(new Insets(9,20,9,20)); hud.setAlignment(Pos.CENTER); hud.setPrefHeight(70);

        VBox vL = new VBox(2); vL.setAlignment(Pos.CENTER_LEFT); vL.setPrefWidth(200);
        Label nL = new Label("★  ARENYS HC"); nL.setStyle(cs("-fx-text-fill:#dd1e1e;-fx-font-size:12px;"));
        lblSL = new Label("0"); lblSL.setStyle(cs("-fx-text-fill:white;-fx-font-size:42px;"));
        vL.getChildren().addAll(nL, lblSL);

        VBox vC = new VBox(3); vC.setAlignment(Pos.CENTER); vC.setPrefWidth(300);
        Label tt = new Label("HOQUEI PATINS  ·  DAM1"); tt.setStyle(cs("-fx-text-fill:#1e2840;-fx-font-size:9px;"));
        lblTime = new Label("2:00"); lblTime.setStyle(cs("-fx-text-fill:#9aaed0;-fx-font-size:34px;"));
        lblMsg = new Label("EL TEU TORN — Arrossega per apuntar"); lblMsg.setStyle(cs("-fx-text-fill:#ffdc30;-fx-font-size:10px;"));
        vC.getChildren().addAll(tt, lblTime, lblMsg);

        VBox vR = new VBox(2); vR.setAlignment(Pos.CENTER_RIGHT); vR.setPrefWidth(200);
        Label nR = new Label("RIVALS FC  ★"); nR.setStyle(cs("-fx-text-fill:#1040c8;-fx-font-size:12px;"));
        lblSR = new Label("0"); lblSR.setStyle(cs("-fx-text-fill:white;-fx-font-size:42px;"));
        vR.getChildren().addAll(nR, lblSR);

        HBox.setHgrow(vL, Priority.ALWAYS); HBox.setHgrow(vR, Priority.ALWAYS);
        hud.getChildren().addAll(vL, vC, vR); return hud;
    }

    // ─── CONTROL BAR ────────────────────────────────
    HBox buildCtrl() {
        HBox bar = new HBox(8); bar.setStyle("-fx-background-color:linear-gradient(to top,#030508,#07101e);");
        bar.setPadding(new Insets(10,18,12,18)); bar.setAlignment(Pos.CENTER);

        bNorm  = mkB("⬛ NORMAL [Q]",  "#164e14", true);
        bCurv  = mkB("↩ EFECTE  [W]",  "#5a4008", false);
        bPow   = mkB("⚡ FORT    [E]",  "#601414", false);
        bPass  = mkB("➡ PASSAR  [P]",  "#103660", false);
        Region sp = new Region(); HBox.setHgrow(sp, Priority.ALWAYS);
        bRew   = mkB("↩ REWIND×3[R]",  "#3e2604", false);
        bShoot = mkB("🏒  TIRA! [SPC]", "#1a5a18", false);
        bShoot.setStyle(bShoot.getStyle()+"-fx-font-size:14px;-fx-min-width:140px;-fx-min-height:48px;");

        bNorm.setOnAction(e  -> setShotType(Shot.NORMAL));
        bCurv.setOnAction(e  -> setShotType(Shot.CURVE));
        bPow.setOnAction(e   -> setShotType(Shot.POWER));
        bPass.setOnAction(e  -> doPass());
        bRew.setOnAction(e   -> doRewind());
        bShoot.setOnAction(e -> doShoot());

        bar.getChildren().addAll(bNorm, bCurv, bPow, bPass, sp, bRew, bShoot);
        return bar;
    }

    Button mkB(String t, String bg, boolean sel) {
        Button b = new Button(t);
        b.setStyle("-fx-font-family:Consolas;-fx-font-size:11px;-fx-font-weight:bold;-fx-text-fill:white;"
                +"-fx-background-color:"+bg+";-fx-background-radius:7;-fx-min-height:42px;"
                +"-fx-min-width:96px;-fx-cursor:hand;"
                +(sel?"-fx-border-color:#ffffffaa;-fx-border-width:2;-fx-border-radius:7;":""));
        b.setFocusTraversable(false); // no roba el focus → tecles sempre actives
        return b;
    }

    void setShotType(Shot s) {
        shotTyp = s;
        for (Button b : new Button[]{bNorm, bCurv, bPow}) b.setStyle(b.getStyle().replaceAll("-fx-border[^;]*;",""));
        Button sel = (s==Shot.NORMAL)?bNorm:(s==Shot.CURVE)?bCurv:bPow;
        sel.setStyle(sel.getStyle()+"-fx-border-color:#ffffffaa;-fx-border-width:2;-fx-border-radius:7;");
    }

    String cs(String e) { return "-fx-font-family:Consolas;-fx-font-weight:bold;"+e; }

    // ─── INPUT ───────────────────────────────────────
    void onPress(MouseEvent e) {
        msPx = e.getSceneX(); msPy = e.getSceneY();
        msAng = aimAng; msPow = aimPow;
        totalDrag = 0; didDrag = false;
    }

    void onDrag(MouseEvent e) {
        double dx = e.getSceneX()-msPx, dy = e.getSceneY()-msPy;
        totalDrag = Math.hypot(dx, dy);
        if (totalDrag > 8 && phase==Phase.MYTURN && humanBall) {
            didDrag = true;
            aimAng  = msAng + Math.toRadians(dx * 0.28);
            aimPow  = Math.max(0.05, Math.min(1.0, msPow - dy/190.0));
            refreshAim();
        }
    }

    void onRelease(MouseEvent e) {
        if (didDrag) {
            // Alliberar drag → XUTA immediatament (com Mini Soccer Star)
            if (phase==Phase.MYTURN && humanBall) doShoot();
            didDrag = false;
        } else {
            // Clic simple → mou el jugador
            if (phase != Phase.MYTURN) return;
            var pr = e.getPickResult();
            if (pr==null || pr.getIntersectedNode()==null) return;
            var lpt = pr.getIntersectedPoint();
            if (lpt==null) return;
            try {
                var wp = pr.getIntersectedNode().localToScene(lpt);
                double ddx = wp.getX()-lx[2], ddz = wp.getZ()-lz[2], d = Math.hypot(ddx,ddz);
                if (d>2) {
                    if (d>150) { ddx=ddx/d*150; ddz=ddz/d*150; }
                    ltx[2] = cl(lx[2]+ddx, -FW/2+14, FW/2-14);
                    ltz[2] = cl(lz[2]+ddz, -FH/2+8,  FH/2-8);
                }
            } catch (Exception ex) {}
        }
    }

    void onKey(KeyEvent e) {
        switch (e.getCode()) {
            case Q -> setShotType(Shot.NORMAL);
            case W -> setShotType(Shot.CURVE);
            case E -> setShotType(Shot.POWER);
            case P -> doPass();
            case R -> doRewind();
            case SPACE, ENTER -> doShoot();
            case A -> { if(phase==Phase.MYTURN){ ltx[2]=cl(lx[2]-55,-FW/2+14,FW/2-14); ltz[2]=lz[2]; } }
            case D -> { if(phase==Phase.MYTURN){ ltx[2]=cl(lx[2]+55,-FW/2+14,FW/2-14); ltz[2]=lz[2]; } }
            case S -> { if(phase==Phase.MYTURN){ ltx[2]=lx[2]; ltz[2]=cl(lz[2]+55,-FH/2+8,FH/2-8); } }
            case F -> { if(phase==Phase.MYTURN){ ltx[2]=lx[2]; ltz[2]=cl(lz[2]-55,-FH/2+8,FH/2-8); } }
            case LEFT  -> camAngle = (camAngle-22+360)%360;
            case RIGHT -> camAngle = (camAngle+22)%360;
            case UP    -> camAngle = 0;
            case DOWN  -> camAngle = 180;
            default -> {}
        }
    }

    // ─── ACCIONS ─────────────────────────────────────
    void doShoot() {
        if (phase != Phase.MYTURN || !humanBall) return;
        // Desa per REWIND
        svBx=bx; svBz=bz; svHx=lx[2]; svHz=lz[2];
        humanBall = false;
        ballFree  = true;
        double nx=Math.cos(aimAng), nz=Math.sin(aimAng);
        double base = switch(shotTyp) { case NORMAL->SPD_N; case CURVE->SPD_C; default->SPD_P; };
        double spd  = 80 + aimPow*(base-80);
        bvx = nx*spd; bvz = nz*spd;
        cfx = (shotTyp==Shot.CURVE) ? -nz*80 : 0;
        cfz = (shotTyp==Shot.CURVE) ?  nx*80 : 0;
        setPhase(Phase.SHOOTING);
    }

    void doPass() {
        if (phase!=Phase.MYTURN || !humanBall) return;
        int t = (Math.hypot(lx[0]-lx[2],lz[0]-lz[2]) < Math.hypot(lx[1]-lx[2],lz[1]-lz[2])) ? 0 : 1;
        humanBall=false; ballFree=true; cfx=0; cfz=0;
        double dx=lx[t]-bx, dz=lz[t]-bz, d=Math.hypot(dx,dz);
        if (d<1) { humanBall=true; ballFree=false; return; }
        bvx=dx/d*290; bvz=dz/d*290;
        setPhase(Phase.SHOOTING);
    }

    void doRewind() {
        if (rewinds<=0 || phase==Phase.MYTURN) return;
        rewinds--; bRew.setText("↩ REWIND×"+rewinds+"[R]");
        bx=svBx; bz=svBz; bvx=0; bvz=0; cfx=0; cfz=0;
        lx[2]=svHx; lz[2]=svHz; ltx[2]=svHx; ltz[2]=svHz;
        humanBall=true; ballFree=false;
        setPhase(Phase.MYTURN);
    }

    // ─── FASES ───────────────────────────────────────
    void setPhase(Phase p) {
        phase = p;
        boolean my = (p==Phase.MYTURN);
        for (Button b : new Button[]{bNorm,bCurv,bPow,bPass,bShoot}) b.setDisable(!my);
        bRew.setDisable(rewinds<=0 || my);
        switch (p) {
            case MYTURN   -> { msg("EL TEU TORN — Arrossega per apuntar + allibera per xutar","#ffdc30"); refreshAim(); }
            case SHOOTING -> { aimGroup.setVisible(false); msg("LLANÇAMENT...","#ff8828"); }
            case AI_TURN  -> {
                aimGroup.setVisible(false); msg("TORN RIVAL","#4480ff");
                PauseTransition d = new PauseTransition(Duration.millis(600+Math.random()*700));
                d.setOnFinished(ev -> aiShoot()); d.play();
            }
            case GOAL, OVER -> aimGroup.setVisible(false);
        }
    }

    void msg(String t, String c) {
        lblMsg.setText(t);
        lblMsg.setStyle(cs("-fx-text-fill:"+c+";-fx-font-size:10px;"));
    }

    // ─── POSICIONS INICIALS ──────────────────────────
    void initPos(boolean lk) {
        setP(lx,lz,ltx,ltz, 0, -FW/2+42,  0);  // GK local
        setP(lx,lz,ltx,ltz, 1, -130,       0);  // DEF local
        setP(lx,lz,ltx,ltz, 2,  -44,       0);  // FW local (humà)
        setP(rx,rz,rtx,rtz, 0,  FW/2-42,   0);  // GK rival
        setP(rx,rz,rtx,rtz, 1,  130,        0);  // DEF rival
        setP(rx,rz,rtx,rtz, 2,   44,        0);  // FW rival
        humanBall=false; rivalBall=false; rHolder=-1;
        bx=0; bz=0; bvx=0; bvz=0; cfx=0; cfz=0; ballFree=false;
        aimAng=0; aimPow=0.60;
        if (lk) {
            humanBall=true; bx=lx[2]+18; bz=lz[2];
            setPhase(Phase.MYTURN);
        } else {
            rivalBall=true; rHolder=2; bx=rx[2]-18; bz=rz[2];
            PauseTransition d = new PauseTransition(Duration.millis(500));
            d.setOnFinished(e -> setPhase(Phase.AI_TURN)); d.play();
        }
    }

    void setP(double[]x,double[]z,double[]tx,double[]tz,int i,double xv,double zv){x[i]=xv;z[i]=zv;tx[i]=xv;tz[i]=zv;}

    // ─── GAME LOOP ───────────────────────────────────
    void startLoop() {
        loop = new AnimationTimer() {
            @Override public void handle(long now) {
                if (lastNs<0) { lastNs=now; return; }
                double dt = Math.min((now-lastNs)/1e9, 0.05);
                lastNs = now;
                if (phase!=Phase.OVER) tick(dt);
            }
        };
        loop.start();
    }

    void tick(double dt) {
        if (phase!=Phase.GOAL) {
            timeLeft = Math.max(0, timeLeft-dt);
            lblTime.setText(String.format("%d:%02d",(int)(timeLeft/60),(int)(timeLeft%60)));
            if (timeLeft<=0) { setPhase(Phase.OVER); onOver(); }
        }
        tickBall(dt);
        tickAI(dt);
        checkGoal();
        tickCam();
        syncScene();
    }

    // ─── FÍSICA PILOTA ───────────────────────────────
    void tickBall(double dt) {
        // Pilota adherida al posseïdor
        if (humanBall && phase==Phase.MYTURN) {
            bx = lx[2]+18; bz = lz[2]; bvx=0; bvz=0; return;
        }
        if (rivalBall && rHolder>=0) {
            bx = rx[rHolder]-18; bz = rz[rHolder]; bvx=0; bvz=0; return;
        }
        if (!ballFree) return;

        // Efecte de corba
        if (shotTyp==Shot.CURVE) {
            bvx+=cfx*dt; bvz+=cfz*dt;
            double dc = Math.pow(0.88, dt*60); cfx*=dc; cfz*=dc;
        }

        bx += bvx*dt; bz += bvz*dt;
        double fr = Math.pow(FRIC, dt*60); bvx*=fr; bvz*=fr;

        // Rebots a les bandes
        double wx=FW/2+2-BR, wz=FH/2+2-BR;
        if (Math.abs(bx)>wx) { bvx*=-0.62; bx=Math.signum(bx)*wx; }
        if (Math.abs(bz)>wz) { bvz*=-0.62; bz=Math.signum(bz)*wz; }

        // Parades dels porters
        if (dist(bx,bz,lx[0],lz[0])<36 && Math.hypot(bvx,bvz)>20) { bvx*=-0.48; bvz+=(Math.random()-0.5)*110; clampBall(145); }
        if (dist(bx,bz,rx[0],rz[0])<36 && Math.hypot(bvx,bvz)>20) { bvx*=-0.48; bvz+=(Math.random()-0.5)*110; clampBall(145); }

        // Recollida (durant SHOOTING)
        if (phase==Phase.SHOOTING) {
            for (int i=0; i<3; i++) {
                if (dist(bx,bz,lx[i],lz[i]) < 32) {
                    ballFree = false;
                    if (i==2) { humanBall=true; setPhase(Phase.MYTURN); }
                    else {
                        PauseTransition d = new PauseTransition(Duration.millis(350));
                        d.setOnFinished(ev->{ humanBall=true; bx=lx[2]+18; bz=lz[2]; setPhase(Phase.MYTURN); });
                        d.play();
                    }
                    return;
                }
            }
            for (int i=0; i<3; i++) {
                if (dist(bx,bz,rx[i],rz[i]) < 32) {
                    ballFree=false; rivalBall=true; rHolder=i; setPhase(Phase.AI_TURN); return;
                }
            }
            // Pilota aturada → tornar al human
            if (Math.hypot(bvx,bvz) < 10) { ballFree=false; humanBall=true; bx=lx[2]+18; bz=lz[2]; setPhase(Phase.MYTURN); }
        }
    }

    void clampBall(double max) { double s=Math.hypot(bvx,bvz); if(s>0&&s<max){bvx=bvx/s*max;bvz=bvz/s*max;} }

    // ─── IA ──────────────────────────────────────────
    void tickAI(double dt) {
        // GK local: queda a la porteria
        mv(lx,lz,ltx,ltz,0, -FW/2+42, cl(bz,-GZ+6,GZ-6), 125, dt);
        // DEF local: cobertura entre rival FW i porteria local
        double deftx = (phase==Phase.AI_TURN||phase==Phase.SHOOTING)
                        ? cl(rx[2]-75,-FW/2+55,-5) : -110;
        mv(lx,lz,ltx,ltz,1, deftx, bz*0.38, 140, dt);
        // Human: si no és el seu torn, persegueix la pilota
        if (phase!=Phase.MYTURN) {
            mv(lx,lz,ltx,ltz,2, bx-22, bz, 165, dt);
        } else {
            // Mou cap al target (WASD / clic)
            double ddx=ltx[2]-lx[2], ddz=ltz[2]-lz[2], d=Math.hypot(ddx,ddz);
            if(d>2){ double s=Math.min(190*dt,d); lx[2]+=ddx/d*s; lz[2]+=ddz/d*s; }
            lx[2]=cl(lx[2],-FW/2+14,FW/2-14); lz[2]=cl(lz[2],-FH/2+8,FH/2-8);
        }

        // GK rival: queda a la seva porteria
        mv(rx,rz,rtx,rtz,0, FW/2-42, cl(bz,-GZ+6,GZ-6), 125, dt);
        // DEF rival: pressiona humà però es queda al camp rival (X>25)
        double rdefTX = Math.max(25, lx[2]+55 + Math.sin(System.currentTimeMillis()*0.002)*22);
        mv(rx,rz,rtx,rtz,1, rdefTX, lz[2]*0.50, 136, dt);
        // FW rival: dribla si té pilota; sinó queda al camp rival (X>18)
        if (phase==Phase.AI_TURN && rivalBall && rHolder==2) {
            double tx=-FW/2+94, tz=Math.sin(System.currentTimeMillis()*0.00082)*55;
            mv(rx,rz,rtx,rtz,2, tx, tz, 152, dt);
        } else if (!rivalBall) {
            mv(rx,rz,rtx,rtz,2, Math.max(18,bx+26), bz*0.75, 140, dt);
        }
    }

    void mv(double[]x,double[]z,double[]tx,double[]tz,int i,double ttx,double ttz,double spd,double dt){
        tx[i]=ttx; tz[i]=ttz;
        double dx=tx[i]-x[i], dz=tz[i]-z[i], d=Math.hypot(dx,dz);
        if (d>2) { double s=Math.min(spd*dt,d); x[i]+=dx/d*s; z[i]+=dz/d*s; }
        x[i]=cl(x[i],-FW/2+12,FW/2-12); z[i]=cl(z[i],-FH/2+8,FH/2-8);
    }

    void aiShoot() {
        if (phase!=Phase.AI_TURN || !rivalBall) return;
        rivalBall=false; ballFree=true; cfx=0; cfz=0;
        double tx=-FW/2-bx, tz=(Math.random()-0.5)*GZ*1.5-bz, d=Math.hypot(tx,tz);
        bvx=tx/d*(240+Math.random()*195); bvz=tz/d*(240+Math.random()*195);
        phase=Phase.SHOOTING;
        msg("LLANÇAMENT RIVAL!","#ff4040");
    }

    // ─── GOL ─────────────────────────────────────────
    void checkGoal() {
        if (phase==Phase.GOAL || phase==Phase.OVER) return;
        if (bx < -FW/2-7 && Math.abs(bz)<GZ) onGoal(false);
        if (bx >  FW/2+7 && Math.abs(bz)<GZ) onGoal(true);
    }

    void onGoal(boolean ls) {
        if (ls) scoreL++; else scoreR++;
        phase=Phase.GOAL; lblSL.setText(""+scoreL); lblSR.setText(""+scoreR);
        msg(ls?"⚽  GOL!  ARENYS HC!":"⚽  GOL!  RIVALS FC!", ls?"#ffdc32":"#ff4040");
        bvx=0; bvz=0; ballFree=false; humanBall=false; rivalBall=false; rHolder=-1;
        Label lb = ls?lblSL:lblSR;
        Timeline fl = new Timeline(
            new KeyFrame(Duration.ZERO,        new KeyValue(lb.scaleXProperty(),1),   new KeyValue(lb.scaleYProperty(),1)),
            new KeyFrame(Duration.millis(200),  new KeyValue(lb.scaleXProperty(),1.95),new KeyValue(lb.scaleYProperty(),1.95)),
            new KeyFrame(Duration.millis(420),  new KeyValue(lb.scaleXProperty(),1),   new KeyValue(lb.scaleYProperty(),1)));
        fl.setCycleCount(3); fl.play();
        PauseTransition d = new PauseTransition(Duration.seconds(2.2));
        d.setOnFinished(e->{ if(timeLeft>0) initPos(!ls); }); d.play();
    }

    void onOver() {
        msg(scoreL>scoreR?"🏆 VICTÒRIA!  "+scoreL+"–"+scoreR:scoreR>scoreL?"💀 DERROTA!  "+scoreL+"–"+scoreR:"🤝 EMPAT!  "+scoreL+"–"+scoreR, "#ffdc32");
    }

    // ─── SYNC VISUAL ────────────────────────────────
    void syncScene() {
        for (int i=0; i<3; i++) {
            // Nodes locals: Y=0 (superfície terra)
            lN[i].setTranslateX(lx[i]); lN[i].setTranslateZ(lz[i]); lN[i].setTranslateY(0);
            // Rivals: girats 180° (miren cap a porteria local)
            rN[i].setTranslateX(rx[i]); rN[i].setTranslateZ(rz[i]); rN[i].setTranslateY(0); rN[i].setRotate(180);
        }
        ballNode.setTranslateX(bx); ballNode.setTranslateZ(bz); ballNode.setTranslateY(-BR+1);
        auraGroup.setTranslateX(lx[2]); auraGroup.setTranslateZ(lz[2]); auraGroup.setVisible(phase==Phase.MYTURN);
        refreshAim();
    }

    // ─── HELPERS ─────────────────────────────────────
    void ab(double w,double h,double d,double x,double y,double z,Color c){
        Box b=new Box(w,h,d); b.setTranslateX(x); b.setTranslateY(y); b.setTranslateZ(z); b.setMaterial(pm(c)); root3D.getChildren().add(b);
    }
    PhongMaterial pm(Color c){ PhongMaterial m=new PhongMaterial(c); m.setSpecularColor(c.brighter()); m.setSpecularPower(18); return m; }
    double cl(double v,double lo,double hi){ return Math.max(lo,Math.min(hi,v)); }
    double dist(double x1,double z1,double x2,double z2){ return Math.hypot(x1-x2,z1-z2); }

    public static void main(String[] args) { launch(args); }
}
