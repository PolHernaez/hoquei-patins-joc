package ui;

import javafx.animation.*;
import javafx.application.Application;
import javafx.geometry.*;
import javafx.scene.*;
import javafx.scene.control.*;
import javafx.scene.layout.*;
import javafx.scene.paint.*;
import javafx.scene.shape.*;
import javafx.scene.transform.*;
import javafx.stage.Stage;
import javafx.util.Duration;
import java.util.*;

/**
 * Hoquei Patins – estil Mini Soccer Star
 *
 * Controls (igual que Mini Soccer Star):
 *   • Arrossega el ratolí → apunta i xuta (fletxa de potència + direcció)
 *   • Clic esquerre (sense drag) → mou el teu jugador al punt del terra
 *
 * Tu controles UN sol jugador (FW vermell, marca ★).
 * Tots els altres (companys + rivals) els controla la IA.
 * Càmera fixa angular: vista de tot el camp.
 */
public class GameWindow extends Application {

    // ═══════════════════════ CONSTANTS ═══════════════════════════════
    static final double FW   = 460; // longitud camp (X)
    static final double FH   = 220; // amplada camp (Z)
    static final double BR   = 10;  // radi pilota
    static final double GZ   = 32;  // semi-amplada porteria (Z)
    static final double GD   = 24;  // profunditat porteria (X)
    static final double GH   = 30;  // alçada porteria

    // Velocitats (unitats/s)
    static final double V_HUMAN   = 190;
    static final double V_AI_ATK  = 162;
    static final double V_AI_DEF  = 148;
    static final double V_GK      = 130;

    // Física pilota
    static final double BALL_FRIC = 0.978; // fricció per frame a 60fps
    static final double BALL_MAX  = 500;

    // ═══════════════════════ ENTITAT ═════════════════════════════════
    enum Role { GK, DEF, MID, FW }

    static class Ent {
        double x, z;           // posició actual
        double tx, tz;         // target (on vol anar)
        double ang;            // angle de cara (graus, eix Y)
        Group  node;
        boolean hasBall;
        boolean human;         // és el jugador humà?
        Role    role;
        double  aiTimer;       // temporitzador IA
    }

    // ═══════════════════════ ESTAT DEL JOC ═══════════════════════════
    List<Ent> locTeam = new ArrayList<>();   // equip local (vermell)
    List<Ent> rivTeam = new ArrayList<>();   // equip rival (blau)
    Ent       human;                         // el jugador que controla l'usuari

    // Pilota
    double bx, bz, bvx, bvz;
    boolean ballFree;
    Ent     pendingReceiver;   // receptor d'una passada en vol

    // Marcador / temps
    int    scoreL, scoreR;
    double timeLeft = 120;
    boolean gameOver, goalPause;

    // ═══════════════════════ ESCENA 3D ═══════════════════════════════
    Group    root3D;
    SubScene sub3D;
    Box      floorBox;
    Group    ballNode;

    // Indicador de xut (fletxa groga)
    Group  aimGroup;
    double aimStartX, aimStartY;   // on ha comencat el drag (píxels pantalla)
    boolean dragging;

    // ═══════════════════════ UI ══════════════════════════════════════
    Label lblScoreL, lblScoreR, lblTime, lblMsg;

    // ═══════════════════════ LOOP ════════════════════════════════════
    AnimationTimer loop;
    long           lastNs = -1;

    // ════════════════════════════════════════════════════════════════
    @Override
    public void start(Stage stage) {
        root3D = new Group();
        sub3D  = new SubScene(root3D, 680, 420, true, SceneAntialiasing.BALANCED);
        sub3D.setFill(Color.rgb(8, 12, 22));

        buildCamera();
        buildField();
        buildGoals();
        buildBall();
        buildAimIndicator();
        buildLights();
        initTeams();
        resetPositions(true);

        BorderPane root = new BorderPane();
        root.setStyle("-fx-background-color:#080c16;");
        root.setTop(buildHUD());
        root.setCenter(new StackPane(sub3D));
        root.setBottom(buildHint());

        Scene scene = new Scene(root, 680, 560);
        setupInput(scene);

        stage.setTitle("Hoquei Patins – Pol Hernáez (DAM1)");
        stage.setScene(scene);
        stage.setResizable(false);
        stage.show();
        startLoop();
    }

    // ─────────────────────────────────────────────────────────────────
    // CÀMERA  (estàtica, angle perfecte per veure tot el camp)
    // ─────────────────────────────────────────────────────────────────
    void buildCamera() {
        PerspectiveCamera cam = new PerspectiveCamera(true);
        cam.setFieldOfView(54);
        cam.setNearClip(1);
        cam.setFarClip(3000);
        // Inclina cap avall -48° i es col·loca enrere
        cam.getTransforms().addAll(
            new Rotate(-48, Rotate.X_AXIS),
            new Translate(0, 0, -620)
        );
        root3D.getChildren().add(cam);
        sub3D.setCamera(cam);
    }

    // ─────────────────────────────────────────────────────────────────
    // CAMP (parquet roller hockey – marró, NO gel blanc)
    // ─────────────────────────────────────────────────────────────────
    void buildField() {
        // Terra de parquet
        floorBox = new Box(FW, 3, FH);
        floorBox.setTranslateY(1.5);
        PhongMaterial fm = new PhongMaterial(Color.rgb(185, 143, 82));
        fm.setSpecularColor(Color.rgb(215, 182, 118));
        fm.setSpecularPower(8);
        floorBox.setMaterial(fm);
        root3D.getChildren().add(floorBox);

        // Línies del camp
        addBox(3, 1.1, FH,       0, 0,  0, Color.rgb(28, 68, 205)); // línia central
        addBox(3, 1.1, FH,  -FW/4, 0,  0, Color.rgb(198, 32, 32)); // zona E
        addBox(3, 1.1, FH,   FW/4, 0,  0, Color.rgb(198, 32, 32)); // zona O

        // Cercle central
        Cylinder cc = cyl(48, 1.3, Color.rgb(28, 68, 205)); root3D.getChildren().add(cc);
        Cylinder cd = cyl(7,  2.2, Color.rgb(198, 32, 32));  root3D.getChildren().add(cd);

        // Punts cara-off
        for (int[] s : new int[][]{{-1,-1},{-1,1},{1,-1},{1,1}}) {
            Cylinder d = cyl(5, 1.6, Color.rgb(198, 32, 32));
            d.setTranslateX(s[0] * FW / 4);
            d.setTranslateZ(s[1] * FH / 3.3);
            root3D.getChildren().add(d);
        }

        // Bandes perimetrals (parets blanques)
        double bh = 28, by = -bh / 2 + 1;
        Color  wc = Color.rgb(192, 196, 212);
        addBox(FW + 18, bh, 7,  0,           by, -FH/2 - 3.5, wc);
        addBox(FW + 18, bh, 7,  0,           by,  FH/2 + 3.5, wc);
        addBox(7, bh, FH,       -FW/2 - 3.5, by,  0,          wc);
        addBox(7, bh, FH,        FW/2 + 3.5, by,  0,          wc);
    }

    // ─────────────────────────────────────────────────────────────────
    // PORTERIES
    // ─────────────────────────────────────────────────────────────────
    void buildGoals() {
        root3D.getChildren().addAll(makeGoal(-FW/2, true), makeGoal(FW/2, false));
    }

    Group makeGoal(double gx, boolean isLocal) {
        Color  c  = isLocal ? Color.rgb(210, 30, 30) : Color.rgb(18, 62, 210);
        Color  nc = isLocal ? Color.rgb(60, 10, 10)  : Color.rgb(8, 10, 60);
        PhongMaterial m = mat(c);
        Box p1 = new Box(5, GH, 5);     p1.setTranslateZ(-GZ);  p1.setTranslateY(-GH/2); p1.setMaterial(m);
        Box p2 = new Box(5, GH, 5);     p2.setTranslateZ( GZ);  p2.setTranslateY(-GH/2); p2.setMaterial(m);
        Box tr = new Box(5, 5, GZ*2+5); tr.setTranslateY(-GH);  tr.setMaterial(m);
        double rx = isLocal ? -GD/2 : GD/2;
        Box r1 = new Box(GD, 5, 5); r1.setTranslateX(rx); r1.setTranslateZ(-GZ); r1.setTranslateY(-GH); r1.setMaterial(m);
        Box r2 = new Box(GD, 5, 5); r2.setTranslateX(rx); r2.setTranslateZ( GZ); r2.setTranslateY(-GH); r2.setMaterial(m);
        Box net = new Box(GD, GH-4, GZ*2); net.setTranslateX(rx); net.setTranslateY(-GH/2+2); net.setMaterial(mat(nc));
        Group g = new Group(p1, p2, tr, r1, r2, net);
        g.setTranslateX(gx);
        return g;
    }

    // ─────────────────────────────────────────────────────────────────
    // PILOTA  (taronja, gran, inconfusible)
    // ─────────────────────────────────────────────────────────────────
    void buildBall() {
        Sphere bs = new Sphere(BR);
        PhongMaterial bm = new PhongMaterial(Color.rgb(255, 115, 8));
        bm.setSpecularColor(Color.rgb(255, 210, 120)); bm.setSpecularPower(75);
        bs.setMaterial(bm);
        Cylinder stripe = new Cylinder(BR - 2, 4);
        stripe.setMaterial(mat(Color.rgb(20, 20, 20)));
        Cylinder shadow = new Cylinder(BR + 4, 1.4);
        shadow.setMaterial(mat(Color.rgb(20, 14, 6))); shadow.setTranslateY(BR);
        ballNode = new Group(shadow, bs, stripe);
        root3D.getChildren().add(ballNode);
    }

    // ─────────────────────────────────────────────────────────────────
    // INDICADOR D'AIM (fletxa groga, apareix al fer drag)
    // ─────────────────────────────────────────────────────────────────
    void buildAimIndicator() {
        PhongMaterial am = mat(Color.rgb(255, 228, 30));

        // Cos de la fletxa (cilindre horitzontal)
        Cylinder shaft = new Cylinder(3.5, 100);
        shaft.getTransforms().add(new Rotate(90, Rotate.Z_AXIS));
        shaft.setTranslateX(50); shaft.setTranslateY(-6);
        shaft.setMaterial(am);

        // Cap de la fletxa (con → simulo amb Cylinder estret)
        Cylinder tip = new Cylinder(0, 16);  // con (radi 0 a un extrem)
        tip.getTransforms().add(new Rotate(90, Rotate.Z_AXIS));
        tip.setTranslateX(102); tip.setTranslateY(-6);
        tip.setMaterial(am);

        // Punts de trajectòria
        List<Sphere> dots = new ArrayList<>();
        for (int i = 1; i <= 5; i++) {
            Sphere d = new Sphere(4);
            d.setTranslateX(125 + i * 26); d.setTranslateY(-6);
            d.setMaterial(am); dots.add(d);
        }

        aimGroup = new Group(shaft, tip);
        aimGroup.getChildren().addAll(dots);
        aimGroup.setVisible(false);
        root3D.getChildren().add(aimGroup);
    }

    // ─────────────────────────────────────────────────────────────────
    // LLUMS
    // ─────────────────────────────────────────────────────────────────
    void buildLights() {
        AmbientLight al = new AmbientLight(Color.rgb(108, 108, 108));
        PointLight   p1 = new PointLight(Color.rgb(255, 244, 210));
        p1.setTranslateY(-520); p1.setTranslateX(-100);
        PointLight   p2 = new PointLight(Color.rgb(152, 180, 248));
        p2.setTranslateY(-360); p2.setTranslateX(200); p2.setTranslateZ(-60);
        root3D.getChildren().addAll(al, p1, p2);
    }

    // ─────────────────────────────────────────────────────────────────
    // JUGADORS
    // ─────────────────────────────────────────────────────────────────
    void initTeams() {
        // Local (vermell): GK + DEF + FW (humà)
        Ent lgk  = mkEnt(Role.GK,  false, Color.rgb(210,30,30), Color.rgb(120,120,120), Color.YELLOW);
        Ent ldef = mkEnt(Role.DEF, false, Color.rgb(210,30,30), Color.rgb(120,120,120), Color.rgb(165,20,20));
        Ent lfw  = mkEnt(Role.FW,  true,  Color.rgb(210,30,30), Color.rgb(120,120,120), Color.rgb(165,20,20));
        locTeam.addAll(List.of(lgk, ldef, lfw));
        human = lfw;

        // Rival (blau): GK + DEF + FW (tots IA)
        Ent rgk  = mkEnt(Role.GK,  false, Color.rgb(18,62,210), Color.rgb(90,90,90), Color.YELLOW);
        Ent rdef = mkEnt(Role.DEF, false, Color.rgb(18,62,210), Color.rgb(90,90,90), Color.rgb(12,38,160));
        Ent rfw  = mkEnt(Role.FW,  false, Color.rgb(18,62,210), Color.rgb(90,90,90), Color.rgb(12,38,160));
        rivTeam.addAll(List.of(rgk, rdef, rfw));

        for (Ent e : locTeam) root3D.getChildren().add(e.node);
        for (Ent e : rivTeam) root3D.getChildren().add(e.node);
    }

    Ent mkEnt(Role role, boolean isHuman, Color jersey, Color shorts, Color helmColor) {
        Ent e = new Ent();
        e.role  = role;
        e.human = isHuman;
        e.node  = buildPlayerNode(jersey, shorts, helmColor, isHuman);
        return e;
    }

    Group buildPlayerNode(Color jersey, Color shorts, Color helmColor, boolean isHuman) {
        // Ombra terra
        Cylinder shadow = cyl(16, 1, Color.rgb(22, 15, 6));
        shadow.setTranslateY(2.5);

        // Patins (roller skates – 4 rodes per peu)
        Box sk1 = new Box(8, 4, 18); sk1.setTranslateX(-5.5); sk1.setTranslateY(-22); sk1.setMaterial(mat(Color.rgb(12,12,12)));
        Box sk2 = new Box(8, 4, 18); sk2.setTranslateX( 5.5); sk2.setTranslateY(-22); sk2.setMaterial(mat(Color.rgb(12,12,12)));
        List<Node> wheels = new ArrayList<>();
        for (double sx : new double[]{-5.5, 5.5})
            for (double sz : new double[]{-7, 7}) {
                Cylinder w = cyl(3, 4.5, Color.rgb(55,55,55));
                w.setTranslateX(sx); w.setTranslateZ(sz); w.setTranslateY(-26);
                w.getTransforms().add(new Rotate(90, Rotate.X_AXIS));
                wheels.add(w);
            }

        // Cames
        Cylinder leg1 = cyl(4.5, 20, shorts); leg1.setTranslateX(-5.5); leg1.setTranslateY(-11);
        Cylinder leg2 = cyl(4.5, 20, shorts); leg2.setTranslateX( 5.5); leg2.setTranslateY(-11);

        // Cos (samarreta)
        Cylinder body = cyl(12, 24, jersey); body.setTranslateY(-34);

        // Coll + cap (pell)
        Cylinder neck = cyl(5, 7, Color.rgb(210,168,128)); neck.setTranslateY(-48);
        Sphere   head = new Sphere(10); head.setTranslateY(-60); head.setMaterial(mat(Color.rgb(210,168,128)));

        // Casc (color equip)
        Sphere helm = new Sphere(12.5); helm.setTranslateY(-61); helm.setScaleZ(0.82);
        PhongMaterial hm = new PhongMaterial(helmColor);
        hm.setSpecularColor(Color.WHITE); hm.setSpecularPower(60);
        helm.setMaterial(hm);

        // Estick de fusta + pala
        Cylinder stick = cyl(2.5, 54, Color.rgb(92, 56, 16));
        stick.setTranslateX(15); stick.setTranslateY(-21);
        stick.getTransforms().add(new Rotate(24, Rotate.Z_AXIS));
        Box blade = new Box(14, 4, 6);
        blade.setTranslateX(18); blade.setTranslateY(-4); blade.setMaterial(mat(Color.rgb(48, 22, 6)));

        // Marcador del jugador humà (estrella groga sota els peus)
        Group marker = new Group();
        if (isHuman) {
            Cylinder star = cyl(19, 2.5, Color.rgb(255, 210, 0));
            star.setTranslateY(4);
            // Anell exterior
            Cylinder ring = cyl(24, 1.5, Color.rgb(210, 160, 0));
            ring.setTranslateY(4.5);
            marker.getChildren().addAll(star, ring);
        }

        Group g = new Group(shadow, sk1, sk2, leg1, leg2, body, neck, head, helm, stick, blade, marker);
        g.getChildren().addAll(wheels);
        return g;
    }

    // ─────────────────────────────────────────────────────────────────
    // HUD
    // ─────────────────────────────────────────────────────────────────
    HBox buildHUD() {
        HBox hud = new HBox();
        hud.setStyle("-fx-background-color:linear-gradient(to bottom,#141c32,#0c1020);");
        hud.setPadding(new Insets(8, 18, 8, 18));
        hud.setAlignment(Pos.CENTER); hud.setPrefHeight(68);

        VBox vL = new VBox(2); vL.setAlignment(Pos.CENTER_LEFT); vL.setPrefWidth(200);
        Label nL = new Label("Arenys HC"); nL.setStyle("-fx-font-size:13px;-fx-font-weight:bold;-fx-text-fill:#d41e1e;");
        lblScoreL = new Label("0"); lblScoreL.setStyle("-fx-font-size:36px;-fx-font-weight:bold;-fx-text-fill:white;");
        vL.getChildren().addAll(nL, lblScoreL);

        VBox vC = new VBox(2); vC.setAlignment(Pos.CENTER); vC.setPrefWidth(280);
        Label tt = new Label("HOQUEI PATINS"); tt.setStyle("-fx-font-size:10px;-fx-text-fill:#484e68;-fx-font-weight:bold;");
        lblTime = new Label("2:00"); lblTime.setStyle("-fx-font-size:28px;-fx-font-weight:bold;-fx-text-fill:#b8c0d8;");
        lblMsg  = new Label("Arrossega per xutar  ·  Clic per moure");
        lblMsg.setStyle("-fx-font-size:10.5px;-fx-font-style:italic;-fx-text-fill:#484e68;");
        vC.getChildren().addAll(tt, lblTime, lblMsg);

        VBox vR = new VBox(2); vR.setAlignment(Pos.CENTER_RIGHT); vR.setPrefWidth(200);
        Label nR = new Label("Rivals FC"); nR.setStyle("-fx-font-size:13px;-fx-font-weight:bold;-fx-text-fill:#1242c4;");
        lblScoreR = new Label("0"); lblScoreR.setStyle("-fx-font-size:36px;-fx-font-weight:bold;-fx-text-fill:white;");
        vR.getChildren().addAll(nR, lblScoreR);

        HBox.setHgrow(vL, Priority.ALWAYS); HBox.setHgrow(vR, Priority.ALWAYS);
        hud.getChildren().addAll(vL, vC, vR);
        return hud;
    }

    HBox buildHint() {
        HBox h = new HBox(22);
        h.setStyle("-fx-background-color:#040608;");
        h.setPadding(new Insets(5, 16, 6, 16)); h.setAlignment(Pos.CENTER);
        for (String t : new String[]{
            "★ = el teu jugador (vermell)",
            "🖱 Arrossega → apunta i xuta (com Mini Soccer Star)",
            "🖱 Clic → mou el teu jugador"
        }) {
            Label l = new Label(t); l.setStyle("-fx-font-size:11px;-fx-text-fill:#343850;");
            h.getChildren().add(l);
        }
        return h;
    }

    // ─────────────────────────────────────────────────────────────────
    // INPUT  (estil Mini Soccer Star: drag = apunta+xuta, clic = mou)
    // ─────────────────────────────────────────────────────────────────
    void setupInput(Scene scene) {
        // Guardem on comença el drag (en píxels de pantalla)
        sub3D.setOnMousePressed(e -> {
            aimStartX = e.getSceneX();
            aimStartY = e.getSceneY();
            dragging  = false;
        });

        sub3D.setOnMouseDragged(e -> {
            if (gameOver || goalPause) return;
            double dx = e.getSceneX() - aimStartX;
            double dy = e.getSceneY() - aimStartY;
            double dist = Math.hypot(dx, dy);
            if (dist > 8) {
                dragging = true;
                updateAimArrow(dx, dy, dist);
            }
        });

        sub3D.setOnMouseReleased(e -> {
            aimGroup.setVisible(false);
            if (gameOver || goalPause) return;
            if (dragging) {
                // XUTA en la direcció del drag (com Mini Soccer Star)
                double dx = e.getSceneX() - aimStartX;
                double dy = e.getSceneY() - aimStartY;
                shoot(dx, dy);
                dragging = false;
            } else {
                // CLIC simple: mou el teu jugador al punt del terra clicat
                Node picked = e.getPickResult().getIntersectedNode();
                if (picked == floorBox) {
                    Point3D pt = e.getPickResult().getIntersectedPoint();
                    human.tx = clamp(pt.getX(), -FW/2+15, FW/2-15);
                    human.tz = clamp(pt.getZ(), -FH/2+10, FH/2-10);
                }
            }
        });
    }

    // Actualitza la fletxa d'aim en 3D basant-se en el drag de pantalla
    void updateAimArrow(double screenDx, double screenDy, double screenDist) {
        if (!human.hasBall) { aimGroup.setVisible(false); return; }

        // La càmera mira des de -X-Z cap a +X+Z, inclinada 48°.
        // Mapping aproximat: screenX → món X, screenY → món Z (invertit per perspectiva)
        double worldDx = screenDx * 1.4;
        double worldDz = screenDy * 1.4;    // drag avall → pilota va cap a lluny
        double mag = Math.hypot(worldDx, worldDz);
        if (mag < 1) { aimGroup.setVisible(false); return; }

        // Potència limitada: maxim MAX_DRAG pixels → velocitat màxima
        double power = Math.min(screenDist / 120.0, 1.0);  // 0..1

        // Orienta la fletxa al món 3D
        double angRad = Math.atan2(worldDz, worldDx);
        double angDeg = Math.toDegrees(angRad);

        aimGroup.setTranslateX(bx);
        aimGroup.setTranslateZ(bz);
        aimGroup.setTranslateY(-5);
        aimGroup.setRotate(angDeg);        // rotació sobre Y (JavaFX)
        aimGroup.setScaleX(0.5 + power * 0.9);  // escala reflecteix potència
        aimGroup.setVisible(true);
    }

    // Executa el xut
    void shoot(double screenDx, double screenDy) {
        if (!human.hasBall) return;
        human.hasBall = false;
        ballFree = true;
        pendingReceiver = null;

        double worldDx = screenDx * 1.4;
        double worldDz = screenDy * 1.4;
        double mag = Math.hypot(worldDx, worldDz);
        if (mag < 1) { worldDx = 1; worldDz = 0; mag = 1; }

        double screenDist = Math.hypot(screenDx, screenDy);
        double power = Math.min(screenDist / 120.0, 1.0) * BALL_MAX;
        power = Math.max(power, 120);  // mínim de potència

        bvx = worldDx / mag * power;
        bvz = worldDz / mag * power;
    }

    // ─────────────────────────────────────────────────────────────────
    // POSICIONS INICIALS
    // ─────────────────────────────────────────────────────────────────
    void resetPositions(boolean localKickoff) {
        // Local: GK esquerra, DEF mig-esquerra, FW (humà) centre-esquerra
        placeEnt(locTeam.get(0), -FW/2+32, 0);              // GK
        placeEnt(locTeam.get(1), -130,      0);              // DEF
        placeEnt(locTeam.get(2),  -45,      0);              // FW (humà)

        // Rival: GK dreta, DEF mig-dreta, FW centre-dreta
        placeEnt(rivTeam.get(0),  FW/2-32, 0);              // GK
        placeEnt(rivTeam.get(1),  130,      0);              // DEF
        placeEnt(rivTeam.get(2),   45,      0);              // FW (IA)

        for (Ent e : allEnts()) e.hasBall = false;
        bx = 0; bz = 0; bvx = 0; bvz = 0;
        ballFree   = false;
        pendingReceiver = null;

        if (localKickoff) {
            human.hasBall = true;
            bx = human.x; bz = human.z;
        } else {
            rivTeam.get(2).hasBall = true;
            bx = rivTeam.get(2).x; bz = rivTeam.get(2).z;
        }
    }

    void placeEnt(Ent e, double x, double z) { e.x=x; e.z=z; e.tx=x; e.tz=z; e.ang=0; e.aiTimer=0; }

    // ─────────────────────────────────────────────────────────────────
    // GAME LOOP
    // ─────────────────────────────────────────────────────────────────
    void startLoop() {
        loop = new AnimationTimer() {
            @Override public void handle(long now) {
                if (lastNs < 0) { lastNs = now; return; }
                double dt = Math.min((now - lastNs) / 1_000_000_000.0, 0.05);
                lastNs = now;
                if (!gameOver && !goalPause) tick(dt);
            }
        };
        loop.start();
    }

    void tick(double dt) {
        tickTimer(dt);
        tickBall(dt);
        tickHuman(dt);
        tickAI(dt);
        checkGoal();
        syncScene();
    }

    // ─────────────────────────────────────────────────────────────────
    // TIMER
    // ─────────────────────────────────────────────────────────────────
    void tickTimer(double dt) {
        timeLeft = Math.max(0, timeLeft - dt);
        int m = (int)(timeLeft / 60), s = (int)(timeLeft % 60);
        lblTime.setText(String.format("%d:%02d", m, s));
        if (timeLeft <= 0) { gameOver = true; onGameOver(); }
    }

    // ─────────────────────────────────────────────────────────────────
    // FÍSICA PILOTA
    // ─────────────────────────────────────────────────────────────────
    void tickBall(double dt) {
        Ent holder = holder();
        if (holder != null) {
            // La pilota va just davant del jugador que la té
            double rad = Math.toRadians(holder.ang);
            bx = holder.x + Math.cos(rad) * 22;
            bz = holder.z + Math.sin(rad) * 22;
            bvx = 0; bvz = 0;
            return;
        }
        if (!ballFree) return;

        bx += bvx * dt;
        bz += bvz * dt;

        // Fricció
        double fric = Math.pow(BALL_FRIC, dt * 60);
        bvx *= fric; bvz *= fric;

        // Rebots a les bandes
        double wx = FW/2 + 2 - BR, wz = FH/2 + 2 - BR;
        if (Math.abs(bx) > wx) { bvx *= -0.62; bx = Math.signum(bx) * wx; }
        if (Math.abs(bz) > wz) { bvz *= -0.62; bz = Math.signum(bz) * wz; }

        // Recollida: primer el receptor de passada, llavors qualsevol
        for (Ent e : allEnts()) {
            if (pendingReceiver != null && e != pendingReceiver) continue;
            if (e.role == Role.GK) continue;
            double d = Math.hypot(bx - e.x, bz - e.z);
            if (d < 28) {
                e.hasBall = true; ballFree = false; pendingReceiver = null;
                if (e == human) {
                    msg("Tens la pilota! Arrossega per xutar.");
                }
                return;
            }
        }
    }

    Ent holder() {
        for (Ent e : allEnts()) if (e.hasBall) return e;
        return null;
    }

    List<Ent> allEnts() {
        List<Ent> all = new ArrayList<>(locTeam);
        all.addAll(rivTeam);
        return all;
    }

    // ─────────────────────────────────────────────────────────────────
    // HUMÀ:  es mou cap al target (clic del ratolí) o cap a la pilota
    // ─────────────────────────────────────────────────────────────────
    void tickHuman(double dt) {
        if (!human.hasBall && !ballFree && holder() == null) {
            // Pilota quieta però ningú la té (situació rara) → va a recollir-la
            human.tx = bx; human.tz = bz;
        }
        if (!human.hasBall && ballFree) {
            // Va cap a la pilota (com Mini Soccer Star: el jugador s'apropa sol)
            double dx = bx - human.x, dz = bz - human.z, d = Math.hypot(dx, dz);
            if (d > 40) { human.tx = bx; human.tz = bz; }
        }
        moveEnt(human, V_HUMAN, dt);
    }

    // ─────────────────────────────────────────────────────────────────
    // IA  (tots els jugadors menys el humà)
    // ─────────────────────────────────────────────────────────────────
    void tickAI(double dt) {
        for (Ent e : locTeam) if (!e.human) aiLocal(e, dt);
        for (Ent e : rivTeam)              aiRival(e, dt);
    }

    // IA de companys locals (GK + DEF)
    void aiLocal(Ent e, double dt) {
        if (e.role == Role.GK) {
            // Porter: queda a la porteria i segueix la pilota en Z
            e.tx = -FW/2 + 32;
            e.tz = clamp(bz, -GZ + 5, GZ - 5);
            moveEnt(e, V_GK, dt);
            return;
        }
        // DEF: pressiona si el rival té pilota; sinó, posicionament
        Ent rivalHolder = rivHolder();
        if (rivalHolder != null) {
            e.tx = rivalHolder.x + 20;
            e.tz = rivalHolder.z;
        } else {
            e.tx = clamp(bx - 60, -FW/3, 0);
            e.tz = bz;
        }
        moveEnt(e, V_AI_DEF, dt);
    }

    // IA de rivals (GK + DEF + FW)
    void aiRival(Ent e, double dt) {
        if (e.role == Role.GK) {
            e.tx = FW/2 - 32;
            e.tz = clamp(bz, -GZ + 5, GZ - 5);
            moveEnt(e, V_GK, dt);
            return;
        }
        if (e.hasBall) {
            aiRivalDribble(e, dt);
        } else {
            aiRivalOff(e, dt);
        }
    }

    // IA rival amb pilota: dribla serpentejant cap a la porteria local
    void aiRivalDribble(Ent e, double dt) {
        double targetX = -FW/2 + 78;
        double targetZ = Math.sin(e.aiTimer * 0.9) * 48;
        e.tx = targetX; e.tz = targetZ;
        double dx = targetX - e.x, dz = targetZ - e.z;
        double dist = Math.hypot(dx, dz);
        moveEnt(e, V_AI_ATK, dt);
        if (dist > 1) e.ang = Math.toDegrees(Math.atan2(dz, dx));
        e.aiTimer += dt;

        // Xuta quan s'acosta o porta massa temps
        boolean timeToShoot = (dist < 130 && e.aiTimer > 1.8) || e.aiTimer > 4.8;
        if (timeToShoot) {
            e.hasBall = false; ballFree = true; e.aiTimer = 0;
            double sx = -FW/2 - e.x;
            double sz = (Math.random() - 0.5) * 50 - e.z;
            double sd = Math.hypot(sx, sz);
            double sp = 270 + Math.random() * 130;
            bvx = sx/sd * sp; bvz = sz/sd * sp;
        }
    }

    // IA rival sense pilota: va a pressionar o es posiciona
    void aiRivalOff(Ent e, double dt) {
        e.aiTimer = 0;
        Ent lh = locHolder();
        if (lh != null) {
            // Pressiona el local que té la pilota
            double jitter = Math.sin(System.currentTimeMillis() * 0.0018 + e.x * 0.1) * 20;
            e.tx = lh.x + jitter; e.tz = lh.z + jitter * 0.5;
        } else {
            e.tx = bx; e.tz = bz;
        }
        if (e.role == Role.DEF) {
            // DEF rival no baixa del mig camp
            e.tx = clamp(e.tx, 0, FW/2);
        }
        moveEnt(e, e.role == Role.FW ? V_AI_ATK : V_AI_DEF, dt);
    }

    Ent locHolder() { for (Ent e : locTeam) if (e.hasBall) return e; return null; }
    Ent rivHolder() { for (Ent e : rivTeam) if (e.hasBall) return e; return null; }

    // ─────────────────────────────────────────────────────────────────
    // MOVIMENT D'ENTITAT
    // ─────────────────────────────────────────────────────────────────
    void moveEnt(Ent e, double spd, double dt) {
        double dx = e.tx - e.x, dz = e.tz - e.z;
        double d  = Math.hypot(dx, dz);
        if (d > 3) {
            double step = Math.min(spd * dt, d);
            e.x += dx/d * step;
            e.z += dz/d * step;
            e.ang = Math.toDegrees(Math.atan2(dz, dx));
        }
        e.x = clamp(e.x, -FW/2 + 14, FW/2 - 14);
        e.z = clamp(e.z, -FH/2 + 10, FH/2 - 10);
    }

    // ─────────────────────────────────────────────────────────────────
    // DETECCIÓ DE GOL
    // ─────────────────────────────────────────────────────────────────
    void checkGoal() {
        if (bx < -FW/2 - 5 && Math.abs(bz) < GZ) onGoal(false); // gol rival
        if (bx >  FW/2 + 5 && Math.abs(bz) < GZ) onGoal(true);  // gol local
    }

    void onGoal(boolean localScored) {
        if (localScored) scoreL++; else scoreR++;
        lblScoreL.setText(String.valueOf(scoreL));
        lblScoreR.setText(String.valueOf(scoreR));

        String txt = localScored ? "⚽  GOL!  ARENYS HC!" : "⚽  GOL!  RIVALS FC!";
        String col = localScored ? "#ffdc32" : "#ff5050";
        lblMsg.setText(txt);
        lblMsg.setStyle("-fx-font-size:14px;-fx-font-weight:bold;-fx-text-fill:" + col + ";");

        // Para joc 2 s
        goalPause = true; ballFree = false; bvx = 0; bvz = 0;
        aimGroup.setVisible(false);
        for (Ent e : allEnts()) e.hasBall = false;

        // Animació parpelleig del marcador
        Label lbl = localScored ? lblScoreL : lblScoreR;
        Timeline fl = new Timeline(
            new KeyFrame(Duration.ZERO,       new KeyValue(lbl.opacityProperty(), 1)),
            new KeyFrame(Duration.millis(130), new KeyValue(lbl.opacityProperty(), 0.1)),
            new KeyFrame(Duration.millis(270), new KeyValue(lbl.opacityProperty(), 1)),
            new KeyFrame(Duration.millis(420), new KeyValue(lbl.opacityProperty(), 0.1)),
            new KeyFrame(Duration.millis(560), new KeyValue(lbl.opacityProperty(), 1))
        );
        fl.play();

        PauseTransition pt = new PauseTransition(Duration.seconds(2));
        pt.setOnFinished(ev -> {
            resetPositions(!localScored);
            goalPause = false;
            lblMsg.setText("Arrossega per xutar  ·  Clic per moure");
            lblMsg.setStyle("-fx-font-size:10.5px;-fx-font-style:italic;-fx-text-fill:#484e68;");
        });
        pt.play();
    }

    void onGameOver() {
        String msg = scoreL > scoreR ? "🏆 VICTÒRIA!  " + scoreL + "–" + scoreR
                   : scoreR > scoreL ? "💀 DERROTA!  " + scoreL + "–" + scoreR
                                     : "🤝 EMPAT!  "   + scoreL + "–" + scoreR;
        msg(""); // reset style first
        lblMsg.setText(msg);
        lblMsg.setStyle("-fx-font-size:14px;-fx-font-weight:bold;-fx-text-fill:#ffdc32;");
    }

    // ─────────────────────────────────────────────────────────────────
    // SYNC: aplica posicions als nodes 3D
    // ─────────────────────────────────────────────────────────────────
    void syncScene() {
        for (Ent e : locTeam) {
            e.node.setTranslateX(e.x);
            e.node.setTranslateZ(e.z);
            e.node.setTranslateY(-1);
            e.node.setRotate(e.ang);
        }
        for (Ent e : rivTeam) {
            e.node.setTranslateX(e.x);
            e.node.setTranslateZ(e.z);
            e.node.setTranslateY(-1);
            e.node.setRotate(e.ang + 180); // rivals miren en direcció contrària
        }
        ballNode.setTranslateX(bx);
        ballNode.setTranslateZ(bz);
        ballNode.setTranslateY(-BR + 1);
    }

    // ─────────────────────────────────────────────────────────────────
    // HELPERS
    // ─────────────────────────────────────────────────────────────────
    void addBox(double w, double h, double d, double x, double y, double z, Color c) {
        Box b = new Box(w, h, d);
        b.setTranslateX(x); b.setTranslateY(y); b.setTranslateZ(z);
        b.setMaterial(mat(c));
        root3D.getChildren().add(b);
    }

    Cylinder cyl(double r, double h, Color c) {
        Cylinder cy = new Cylinder(r, h); cy.setMaterial(mat(c)); return cy;
    }

    PhongMaterial mat(Color c) {
        PhongMaterial m = new PhongMaterial(c);
        m.setSpecularColor(c.brighter()); m.setSpecularPower(22);
        return m;
    }

    double clamp(double v, double lo, double hi) { return Math.max(lo, Math.min(hi, v)); }

    void msg(String t) {
        lblMsg.setText(t);
        lblMsg.setStyle("-fx-font-size:10.5px;-fx-font-style:italic;-fx-text-fill:#484e68;");
    }

    public static void main(String[] args) { launch(args); }
}
