using Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services.Interfaces.EnviroMonitor
{
    public interface IEnviroMonitorService
    {
        void Run(List<ConfigSetting> configSettings);
    }
}
