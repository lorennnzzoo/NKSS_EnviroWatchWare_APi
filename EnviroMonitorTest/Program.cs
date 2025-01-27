using log4net;
using log4net.Config;
using Models;
using Repositories;
using Repositories.Interfaces;
using Services;
using Services.Interfaces;
using Services.Interfaces.EnviroMonitor;
using Services.Services.EnviroMonitor;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Unity;
using Unity.Lifetime;

namespace EnviroMonitorTest
{
    class Program
    {
        private static readonly ILog logger = LogManager.GetLogger(typeof(Program));
        public const string GROUPNAME = "EnviroMonitor";
        public static IEnviroMonitorService enviroMonitorService;
        public readonly IConfigSettingService configSettingService;

        static List<ConfigSetting> configSettings = new List<ConfigSetting>();
        public Program(IEnviroMonitorService _enviroMonitorService, IConfigSettingService _configSettingService)
        {
            XmlConfigurator.Configure(new System.IO.FileInfo("log4net.config"));
            enviroMonitorService = _enviroMonitorService;
            configSettingService = _configSettingService;
            configSettings = configSettingService.GetConfigSettingsByGroupName(GROUPNAME).ToList();
            if (!configSettings.Any())
            {
                throw new Services.Exceptions.NoRecordsFoundForGroupNameException(GROUPNAME);
            }
        }
        static void Main(string[] args)
        {
            var container = new UnityContainer();

            //company
            container.RegisterType<ICompanyRepository, CompanyRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<ICompanyService, CompanyService>(new HierarchicalLifetimeManager());
            //station
            container.RegisterType<IStationRepository, StationRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IStationService, StationService>(new HierarchicalLifetimeManager());
            //channel
            container.RegisterType<IChannelRepository, ChannelRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IChannelService, ChannelService>(new HierarchicalLifetimeManager());
            //analyzer
            container.RegisterType<IAnalyzerRepository, AnalyzerRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IAnalyzerService, AnalyzerService>(new HierarchicalLifetimeManager());
            //oxide
            container.RegisterType<IOxideRepository, OxideRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IOxideService, OxideService>(new HierarchicalLifetimeManager());
            //monitoring type
            container.RegisterType<IMonitoringTypeRepository, MonitoringTypeRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IMonitoringTypeService, MonitoringTypeService>(new HierarchicalLifetimeManager());
            //scaling factor
            container.RegisterType<IScalingFactorRepository, ScalingFactorRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IScalingFactorService, ScalingFactorService>(new HierarchicalLifetimeManager());
            //channel type
            container.RegisterType<IChannelTypeRepository, ChannelTypeRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IChannelTypeService, ChannelTypeService>(new HierarchicalLifetimeManager());
            //channel data feed
            container.RegisterType<IChannelDataFeedRepository, ChannelDataFeedRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IChannelDataFeedService, ChannelDataFeedService>(new HierarchicalLifetimeManager());
            //report 
            container.RegisterType<IReportRepository, ReportRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IReportService, ReportService>(new HierarchicalLifetimeManager());
            //user
            container.RegisterType<IUserRepository, UserRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IUserService, UserService>(new HierarchicalLifetimeManager());
            //crypto

            container.RegisterType<ICryptoService, CryptoService>(new HierarchicalLifetimeManager());
            //license
            container.RegisterType<ILicenseRepository, LicenseRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<ILicenseService, LicenseService>(new HierarchicalLifetimeManager());
            //role
            container.RegisterType<IRoleRepository, RoleRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IRoleService, RoleService>(new HierarchicalLifetimeManager());
            //config setting
            container.RegisterType<IConfigSettingRepository, ConfigSettingRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IConfigSettingService, ConfigSettingService>(new HierarchicalLifetimeManager());
            container.RegisterType<IEnviroMonitorService, EnviroMonitorService>(new HierarchicalLifetimeManager());
            // Resolve Program with dependencies
            var program = container.Resolve<Program>();
            try
            {
                while (true)
                {    
                    enviroMonitorService.Run(configSettings);
                    Thread.Sleep(GetIntervalFromConfig());
                }
            }
            catch(Exception ex)
            {
                logger.Error($"Error at Main", ex);
            }
        }
        private static int GetIntervalFromConfig()
        {
            var intervalSetting = configSettings.FirstOrDefault(s => s.ContentName == "ServiceInterval");
            if (intervalSetting != null && int.TryParse(intervalSetting.ContentValue, out int interval))
            {
                return interval*1000;
            }
            logger.Info($"Service Interval not found using default 60seconds");
            return 60000; // Default to 1 minute
        }
    }
}
