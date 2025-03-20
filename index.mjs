export const handler = async (event) => {
    const name = event.name || "Inconnu"; // Récupération du nom depuis l'événement
    const time = new Date().toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" }); // Heure actuelle formatée

    return {
        statusCode: 200,
        body: JSON.stringify(`Hello World ! Ici ${name}, à ${time}`),
    };
};