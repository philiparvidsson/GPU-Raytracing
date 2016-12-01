namespace GpuRaytrace {

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
    public static void Main(string[] args) {
        Game.Inst.Run(new SharpDXGraphicsMgr(),
                      new SharpDXSoundMgr(),
                      "GPU-RT",
                      640, 640,
                      new MainScene(args.Length > 0 ? args[0] : null));
    }
}

}
