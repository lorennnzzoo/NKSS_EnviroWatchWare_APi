using NKSS_EnviroWatchWare_APi.Logging;
using Repositories;
using Repositories.Interfaces;
using Services;
using Services.Interfaces;
using System.Web.Http;
using System.Web.Http.Cors;
using Unity;
using Unity.Lifetime;
using Unity.WebApi;

namespace NKSS_EnviroWatchWare_APi
{
    public static class WebApiConfig
    {       
        public static void Register(HttpConfiguration config)
        {
            // Web API configuration and services
            // 

            //var corsAttr = new EnableCorsAttribute("http://localhost:4200", // Origins
            //"accept,authorization,content-type,origin", // Headers
            //"GET,POST,PUT,DELETE,OPTIONS"); // Methods
            //config.EnableCors(corsAttr);



            //config.Filters.Add(new LoggingFilter());
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
            //service logs
            container.RegisterType<IServiceLogsRepository, ServiceLogsRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IServiceLogsService, ServiceLogsService>(new HierarchicalLifetimeManager());
            //configuration 
            container.RegisterType<IConfigurationRepository, ConfigurationRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IConfigurationService, ConfigurationService>(new HierarchicalLifetimeManager());
            //
            // Set up Unity as the Dependency Resolver
            config.DependencyResolver = new UnityDependencyResolver(container);



           

            // Web API routes

            config.MapHttpAttributeRoutes();

            config.Routes.MapHttpRoute(
                name: "DefaultApi",
                routeTemplate: "api/{controller}/{id}",
                defaults: new { id = RouteParameter.Optional }
            );
        }
    }
}
