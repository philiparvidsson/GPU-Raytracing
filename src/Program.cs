namespace ComplexFuncViz {

/*--------------------------------------
 * USINGS
 *------------------------------------*/

using System;

using PrimusGE;
using PrimusGE.Core;
using PrimusGE.Graphics;
using PrimusGE.Graphics.SharpDXImpl;
using PrimusGE.Sound.SharpDXImpl;

/*--------------------------------------
 * CLASSES
 *------------------------------------*/

internal static class Program {
    /*--------------------------------------
     * PUBLIC METHODS
     *------------------------------------*/

    [STAThread]
    public static void Main() {
        Game.Inst.Run(new SharpDXGraphicsMgr(),
                      new SharpDXSoundMgr(),
                      "RTRT - Real-time Raytracing",
                      340, 340,
                      new MainScene());
    }
}

}
