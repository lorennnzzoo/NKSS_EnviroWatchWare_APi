using Repositories;
using Repositories.Interfaces;
using Services;
using Services.Interfaces;
using System.Web.Http;
using Unity;
using Unity.Lifetime;
using Unity.WebApi;

namespace NKSS_EnviroWatchWare_APi
{
    public static class UnityConfig
    {
        public static void RegisterComponents()
        {		
            
            // register all your components with the container here
            // it is NOT necessary to register your controllers
            
            // e.g. container.RegisterType<ITestService, TestService>();                       
            
        }
    }
}