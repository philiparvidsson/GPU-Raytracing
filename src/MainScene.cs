namespace ComplexFuncViz {

/*--------------------------------------
 * USINGS
 *------------------------------------*/

using System;
using System.IO;

using PrimusGE;
using PrimusGE.Core;
using PrimusGE.Graphics;
using PrimusGE.Graphics.Shaders;
using PrimusGE.Subsystems;

/*--------------------------------------
 * CLASSES
 *------------------------------------*/

public class MainScene : Scene {
    /*--------------------------------------
     * NON-PUBLIC CONSTANTS
     *------------------------------------*/

    private const string SHADER = "Raytracer.ps.hlsl";

    /*--------------------------------------
     * NON-PUBLIC FIELDS
     *------------------------------------*/

    private float    m_DoNothingTimer      = 0.0f;
    private Keyboard m_Keyboard            = Keyboard();
    private IShader  m_Shader              = null;
    private DateTime m_ShaderLastWriteTime = default (DateTime);
    private float    m_ShaderUpdateTimer   = 0.0f;
    private float    m_Time                = 0.0f;

    /*--------------------------------------
     * PUBLIC METHODS
     *------------------------------------*/

    public override void Init() {
        SetSubsystems(new PerformanceInfoSubsystem());

        base.Init();

        Game.Inst.Window.Show();

        var g = Game.Inst.Graphics;

        m_Shader = g.ShaderMgr.LoadPS<float>(SHADER);
        m_ShaderLastWriteTime = File.GetLastWriteTime(SHADER);
    }

    public override void Draw(float dt) {
        base.Draw(dt);

        m_DoNothingTimer -= dt;
        if (m_DoNothingTimer < 0.0f) {
            m_DoNothingTimer = 0.0f;
        }

        var g = Game.Inst.Graphics;

        if (m_DoNothingTimer <= 0.0f) {
            g.BeginFrame();
            g.RenderTarget.Clear(Color.Black);

            m_Time += dt;
            m_Shader.SetConstants(m_Time);
            g.ApplyPostFX(g.ScreenRenderTarget, m_Shader);

            g.EndFrame();
        }

        m_ShaderUpdateTimer -= dt;
        if (m_ShaderUpdateTimer <= 0.0f) {
            var lastWriteTime = File.GetLastWriteTime(SHADER);

            if (lastWriteTime > m_ShaderLastWriteTime) {
                m_ShaderLastWriteTime = lastWriteTime;

                IShader shader = null;

                try { shader = g.ShaderMgr.LoadPS<float>(SHADER); }
                catch (Exception e) { Console.WriteLine(e); }

                if (shader != null) {
                    Console.WriteLine("Loaded shader ({0})", lastWriteTime);

                    m_Shader.Dispose();
                    m_Shader = shader;

                    m_DoNothingTimer = 1.0f;
                }
            }

            m_ShaderUpdateTimer = 0.5f;
        }
    }
}

}
