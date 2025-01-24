using Services;
using Services.Interfaces;
using Services.Interfaces.EnviroMonitor;
using Services.Services.EnviroMonitor;
using System;
using System.Collections.Generic;
using System.Linq;
using System.ServiceProcess;
using System.Text;
using System.Threading.Tasks;
using Unity;
using Unity.Lifetime;

namespace NKSS_EnviroMonitor
{
    static class Program
    {
        /// <summary>
        /// The main entry point for the application.
        /// </summary>
        static void Main()
        {
            var container = ConfigureDependencies();

            // Resolve dependencies for the service
            var enviroMonitorService = container.Resolve<IEnviroMonitorService>();
            var configSettingService = container.Resolve<IConfigSettingService>();
            ServiceBase[] ServicesToRun;
            ServicesToRun = new ServiceBase[]
            {
                new NKSS_EnviroMonitor(enviroMonitorService, configSettingService)
            };
            ServiceBase.Run(ServicesToRun);
        }
        /// <summary>
        /// Configures the Unity container and registers dependencies.
        /// </summary>
        /// <returns>IUnityContainer</returns>
        private static IUnityContainer ConfigureDependencies()
        {
            var container = new UnityContainer();

            // Register services with their interfaces
            container.RegisterType<IEnviroMonitorService, EnviroMonitorService>(new HierarchicalLifetimeManager());
            container.RegisterType<IConfigSettingService, ConfigSettingService>(new HierarchicalLifetimeManager());

            return container;
        }
    }
}
