using System;
using System.Collections.Generic;
using System.Linq;
using System.ServiceProcess;
using System.Text;
using System.Threading.Tasks;
using Unity;
using Repositories;
using Repositories.Interfaces;
using Services;
using Services.Interfaces;
using Services.Interfaces.EnviroMonitor;
using Services.Services.EnviroMonitor;
using Unity.Lifetime;

namespace NKSS_EnviroMonitorService
{
    static class Program
    {
        /// <summary>
        /// The main entry point for the application.
        /// </summary>
        //static void Main()
        //{
        //    ServiceBase[] ServicesToRun;
        //    ServicesToRun = new ServiceBase[]
        //    {
        //        new NKSS_EnviroMonitor()
        //    };
        //    ServiceBase.Run(ServicesToRun);
        //}

        //static void Main()
        //{
        //    var container = ConfigureDependencies();

        //    // Resolve dependencies for the service
        //    var enviroMonitorService = container.Resolve<IEnviroMonitorService>();
        //    var configSettingService = container.Resolve<IConfigSettingService>();

        //    // Create the service instance with resolved dependencies
        //    ServiceBase[] ServicesToRun;
        //    ServicesToRun = new ServiceBase[]
        //    {
        //        new NKSS_EnviroMonitor(enviroMonitorService, configSettingService)
        //    };
        //    ServiceBase.Run(ServicesToRun);
        //}
        static void Main()
        {
            #if DEBUG
            var container = ConfigureDependencies();

            // Resolve dependencies for the service
            var enviroMonitorService = container.Resolve<IEnviroMonitorService>();
            var configSettingService = container.Resolve<IConfigSettingService>();

            // Run the service as a console application in debug mode
            var service = new NKSS_EnviroMonitor(enviroMonitorService, configSettingService);
            service.OnDebug();
            System.Threading.Thread.Sleep(System.Threading.Timeout.Infinite);
            #else
                ServiceBase[] ServicesToRun;
                ServicesToRun = new ServiceBase[]
                {
                    new NKSS_EnviroMonitor()
                };
                ServiceBase.Run(ServicesToRun);
            #endif
        }


        /// <summary>
        /// Configures the Unity container and registers dependencies.
        /// </summary>
        /// <returns>IUnityContainer</returns>
        public static IUnityContainer ConfigureDependencies()
        {
            var container = new UnityContainer();

            // Register all dependencies
            container.RegisterType<ICompanyRepository, CompanyRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<ICompanyService, CompanyService>(new HierarchicalLifetimeManager());
            container.RegisterType<IStationRepository, StationRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IStationService, StationService>(new HierarchicalLifetimeManager());
            container.RegisterType<IChannelRepository, ChannelRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IChannelService, ChannelService>(new HierarchicalLifetimeManager());
            container.RegisterType<IAnalyzerRepository, AnalyzerRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IAnalyzerService, AnalyzerService>(new HierarchicalLifetimeManager());
            container.RegisterType<IOxideRepository, OxideRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IOxideService, OxideService>(new HierarchicalLifetimeManager());
            container.RegisterType<IMonitoringTypeRepository, MonitoringTypeRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IMonitoringTypeService, MonitoringTypeService>(new HierarchicalLifetimeManager());
            container.RegisterType<IScalingFactorRepository, ScalingFactorRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IScalingFactorService, ScalingFactorService>(new HierarchicalLifetimeManager());
            container.RegisterType<IChannelTypeRepository, ChannelTypeRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IChannelTypeService, ChannelTypeService>(new HierarchicalLifetimeManager());
            container.RegisterType<IChannelDataFeedRepository, ChannelDataFeedRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IChannelDataFeedService, ChannelDataFeedService>(new HierarchicalLifetimeManager());
            container.RegisterType<IReportRepository, ReportRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IReportService, ReportService>(new HierarchicalLifetimeManager());
            container.RegisterType<IUserRepository, UserRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IUserService, UserService>(new HierarchicalLifetimeManager());
            container.RegisterType<ICryptoService, CryptoService>(new HierarchicalLifetimeManager());
            container.RegisterType<ILicenseRepository, LicenseRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<ILicenseService, LicenseService>(new HierarchicalLifetimeManager());
            container.RegisterType<IRoleRepository, RoleRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IRoleService, RoleService>(new HierarchicalLifetimeManager());
            container.RegisterType<IConfigSettingRepository, ConfigSettingRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IConfigSettingService, ConfigSettingService>(new HierarchicalLifetimeManager());
            container.RegisterType<IEnviroMonitorService, EnviroMonitorService>(new HierarchicalLifetimeManager());

            return container;
        }
    }
}
