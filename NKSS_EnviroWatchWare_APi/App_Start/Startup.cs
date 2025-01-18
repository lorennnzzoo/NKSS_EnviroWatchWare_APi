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

[assembly: OwinStartup(typeof(NKSS_EnviroWatchWare_APi.App_Start.Startup))]

namespace NKSS_EnviroWatchWare_APi.App_Start
{
    public class Startup
    {
        public void Configuration(IAppBuilder app)
        {
            var corsPolicy = new CorsPolicy
            {
                AllowAnyMethod = true,
                AllowAnyHeader = true
            };
            corsPolicy.Origins.Add("http://localhost:4200");

            // Register CORS on the OWIN pipeline
            app.Use(typeof(CorsMiddleware), corsPolicy);
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

            var oauthProvider = container.Resolve<OAuthProvider>();
            var OAuthOptions = new OAuthAuthorizationServerOptions
            {
                AllowInsecureHttp = true,
                TokenEndpointPath = new PathString("/Auth/Login"),
                AccessTokenExpireTimeSpan = TimeSpan.FromMinutes(30), 
                Provider = oauthProvider
            };

            app.UseOAuthBearerTokens(OAuthOptions);
            app.UseOAuthAuthorizationServer(OAuthOptions);
            app.UseOAuthBearerAuthentication(new OAuthBearerAuthenticationOptions());
        }
    }
}
