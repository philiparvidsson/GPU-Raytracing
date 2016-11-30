namespace GpuRaytrace {

/*--------------------------------------
 * USINGS
 *------------------------------------*/

using System;
using System.IO;

using PrimusGE;
using PrimusGE.Core;
using PrimusGE.Graphics;
using PrimusGE.Graphics.Shaders;
using PrimusGE.Input;
using PrimusGE.Subsystems;

/*--------------------------------------
 * STRUCTS
 *------------------------------------*/

 public struct ShaderConstants {
     public float EyeX;
     public float EyeZ;
     public float EyeTheta;

     public float Time;
 }


/*--------------------------------------
 * CLASSES
 *------------------------------------*/

public class MainScene : Scene {
    /*--------------------------------------
     * NON-PUBLIC CONSTANTS
     *------------------------------------*/

    /*--------------------------------------
     * NON-PUBLIC FIELDS
     *------------------------------------*/

    private float           m_DoNothingTimer      = 0.0f;
    private IShader         m_Shader              = null;
    private ShaderConstants m_ShaderConstants     = default (ShaderConstants);
    private DateTime        m_ShaderLastWriteTime = default (DateTime);
    private float           m_ShaderUpdateTimer   = 0.0f;

    /*--------------------------------------
     * PUBLIC PROPERTIES
     *------------------------------------*/

    public string ShaderName { get; set; }

    /*--------------------------------------
     * CONSTRUCTORS
     *------------------------------------*/

    public MainScene(string shaderName) {
        ShaderName = shaderName ?? "Scene1.ps.hlsl";
    }

    /*--------------------------------------
     * PUBLIC METHODS
     *------------------------------------*/

    public override void Init() {
        SetSubsystems(new PerformanceInfoSubsystem());

        base.Init();

        Game.Inst.Window.Show();

        var g = Game.Inst.Graphics;

        m_Shader = g.ShaderMgr.LoadPS<ShaderConstants>(ShaderName);
        m_ShaderLastWriteTime = File.GetLastWriteTime(ShaderName);

        m_ShaderConstants.EyeZ = 0.0f;
        m_ShaderConstants.EyeTheta = 3.141592654f;
    }

    public override void Draw(float dt) {
        base.Draw(dt);

        if (Game.Inst.Graphics.IsLagging) {
            return;
        }

        //System.Threading.Thread.Sleep(10);

        m_DoNothingTimer -= dt;
        if (m_DoNothingTimer < 0.0f) {
            m_DoNothingTimer = 0.0f;
        }

        var kb = Game.Inst.Keyboard;
        var sc = m_ShaderConstants;

        if (kb.IsKeyPressed(Key.W)) {
            var a  = (float)Math.PI / 2.0f;
            var dx = 1.5f*(float)Math.Cos(m_ShaderConstants.EyeTheta + a)*dt;
            var dz = 1.5f*(float)Math.Sin(m_ShaderConstants.EyeTheta + a)*dt;
            m_ShaderConstants.EyeX += dx;
            m_ShaderConstants.EyeZ += dz;
        }

        if (kb.IsKeyPressed(Key.S)) {
            var a  = (float)Math.PI / 2.0f;
            var dx = 1.5f*(float)Math.Cos(m_ShaderConstants.EyeTheta - a)*dt;
            var dz = 1.5f*(float)Math.Sin(m_ShaderConstants.EyeTheta - a)*dt;
            m_ShaderConstants.EyeX += dx;
            m_ShaderConstants.EyeZ += dz;
        }

        if (kb.IsKeyPressed(Key.A)) {
            var dx = 1.5f*(float)Math.Cos(m_ShaderConstants.EyeTheta)*dt;
            var dz = 1.5f*(float)Math.Sin(m_ShaderConstants.EyeTheta)*dt;
            m_ShaderConstants.EyeX -= dx;
            m_ShaderConstants.EyeZ -= dz;
        }

        if (kb.IsKeyPressed(Key.D)) {
            var dx = 1.5f*(float)Math.Cos(m_ShaderConstants.EyeTheta)*dt;
            var dz = 1.5f*(float)Math.Sin(m_ShaderConstants.EyeTheta)*dt;
            m_ShaderConstants.EyeX += dx;
            m_ShaderConstants.EyeZ += dz;
        }

        if (kb.IsKeyPressed(Key.Left)) {
            m_ShaderConstants.EyeTheta += 0.4f * 2.0f*3.141592654f*dt;
        }

        if (kb.IsKeyPressed(Key.Right)) {
            m_ShaderConstants.EyeTheta -= 0.4f * 2.0f*3.141592654f*dt;
        }

        var g = Game.Inst.Graphics;

        if (m_DoNothingTimer <= 0.0f) {
            g.BeginFrame();
            g.RenderTarget.Clear(Color.Black);

            m_ShaderConstants.Time += 0.5f*dt;
            m_Shader.SetConstants(m_ShaderConstants);
            g.ApplyPostFX(g.ScreenRenderTarget, m_Shader);

            g.EndFrame();

            //m_DoNothingTimer = 0.1f;
        }

        m_ShaderUpdateTimer -= dt;
        if (m_ShaderUpdateTimer <= 0.0f) {
            var lastWriteTime = File.GetLastWriteTime(ShaderName);

            if (lastWriteTime > m_ShaderLastWriteTime) {
                m_ShaderLastWriteTime = lastWriteTime;

                IShader shader = null;

                try { shader = g.ShaderMgr.LoadPS<float>(ShaderName); }
                catch (Exception e) { Console.WriteLine(e); }

                if (shader != null) {
                    Console.WriteLine("Loaded shader ({0})", lastWriteTime);

                    m_Shader.Dispose();
                    m_Shader = shader;

                    m_DoNothingTimer = 1.0f;
                }
            }

            m_ShaderUpdateTimer = 7.5f;
        }
    }
}

}
