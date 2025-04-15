using Microsoft.Owin;
using Microsoft.Owin.Security.OAuth;
using Owin;
using System;
using NKSS_EnviroWatchWare_APi.Providers;
using System.Web.Http;

using Services;
using Services.Interfaces;
using Unity;
using Repositories.Interfaces;
using Repositories;
using Unity.Lifetime;
using System.Web.Http.Cors;
using System.Web.Cors;
using NKSS_EnviroWatchWare_APi.MiddlerWare;
using Microsoft.Owin.Cors;
using System.Threading.Tasks;

[assembly: OwinStartup(typeof(NKSS_EnviroWatchWare_APi.App_Start.Startup))]

namespace NKSS_EnviroWatchWare_APi.App_Start
{
    public class Startup
    {
        string origin = System.Configuration.ConfigurationManager.AppSettings["OriginUrl"];
        //public void Configuration(IAppBuilder app)
        //{
        //    var corsPolicy = new CorsPolicy
        //    {
        //        AllowAnyMethod = true,
        //        AllowAnyHeader = true
        //    };
        //    corsPolicy.Origins.Add(origin);

        //    // Register CORS on the OWIN pipeline
        //    app.Use(typeof(CorsMiddleware), corsPolicy);
        //    ConfigureAuth(app);            
        //}
        public void Configuration(IAppBuilder app)
        {
            var corsPolicy = new CorsPolicy
            {
                AllowAnyOrigin=true,
                AllowAnyMethod = true,
                AllowAnyHeader = true,
                SupportsCredentials = true // Required if credentials (e.g., Authorization headers) are used
            };

            //corsPolicy.Origins.Add(origin); // Set the allowed origin explicitly
                                                                // corsPolicy.Origins.Add("*"); // Do NOT use * if you need authentication

            var corsOptions = new CorsOptions
            {
                PolicyProvider = new CorsPolicyProvider
                {
                    PolicyResolver = context => Task.FromResult(corsPolicy)
                }
            };

            app.UseCors(corsOptions); // Use the built-in CORS middleware

            ConfigureAuth(app);
        }

        public void ConfigureAuth(IAppBuilder app)
        {
            var container = new UnityContainer();
            container.RegisterType<IUserRepository, UserRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IUserService, UserService>(new HierarchicalLifetimeManager());
            container.RegisterType<ILicenseRepository, LicenseRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<ILicenseService, LicenseService>(new HierarchicalLifetimeManager());
            container.RegisterType<ICryptoService, CryptoService>(new HierarchicalLifetimeManager());
            container.RegisterType<IRoleRepository, RoleRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IRoleService, RoleService>(new HierarchicalLifetimeManager());
            container.RegisterType<IChannelTypeRepository, ChannelTypeRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IChannelTypeService, ChannelTypeService>(new HierarchicalLifetimeManager());
            container.RegisterType<IMonitoringTypeRepository, MonitoringTypeRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IMonitoringTypeService, MonitoringTypeService>(new HierarchicalLifetimeManager());

            var oauthProvider = container.Resolve<OAuthProvider>();
            var OAuthOptions = new OAuthAuthorizationServerOptions
            {
                AllowInsecureHttp = true,
                TokenEndpointPath = new PathString("/Auth/Login"),
                AccessTokenExpireTimeSpan = TimeSpan.FromDays(1), 
                Provider = oauthProvider
            };

            app.UseOAuthBearerTokens(OAuthOptions);
            app.UseOAuthAuthorizationServer(OAuthOptions);
            app.UseOAuthBearerAuthentication(new OAuthBearerAuthenticationOptions());
        }
    }
}
