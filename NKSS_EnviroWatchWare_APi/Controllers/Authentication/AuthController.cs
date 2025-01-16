using Services;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;

namespace NKSS_EnviroWatchWare_APi.Controllers.Authentication
{
    [Authorize]
    [RoutePrefix("Auth")]
    public class AuthController : ApiController
    {
        private readonly UserService user_service;
        private Helpers.Validator validator = new Helpers.Validator();
        public AuthController(UserService _user_service)
        {
            this.user_service = _user_service;
        }

        [HttpPost]
        [AllowAnonymous]
        [Route("Register")]
        public IHttpActionResult Register(Models.Post.Authentication.User user)
        {
            try
            {
                var result = validator.ValidateProperties(user);
                if (!result.isValid)
                {
                    return BadRequest(result.errorMessage);
                }

                user_service.CreateUser(user);
                return Ok();
            }
            catch(Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }
    }
}
